// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts/interfaces/IERC4626.sol";
import "../interfaces/IDefiAdapter.sol";
import "../interfaces/IOperationTypes.sol";

/**
 * @title ERC4626Adapter
 * @notice 通用 ERC4626 Vault 适配器，支持任何符合 ERC4626 标准的 vault
 * @dev 实现与 ERC4626 vaults 的存款和取款功能，支持 UUPS 升级
 */
contract ERC4626Adapter is 
    Initializable,
    OwnableUpgradeable, 
    UUPSUpgradeable,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable,
    IDefiAdapter 
{
    using SafeERC20 for IERC20;
    
    // ============ 事件定义 ============
    
    event VaultDeposit(
        address indexed user,
        address indexed vault,
        uint256 assets,
        uint256 shares,
        uint256 timestamp
    );
    
    event VaultWithdraw(
        address indexed user,
        address indexed vault,
        uint256 shares,
        uint256 assets,
        uint256 timestamp
    );
    
    // ============ 状态变量 ============
    
    /// @notice 支持的 ERC4626 Vault 地址映射
    mapping(address => bool) public supportedVaults;
    
    /// @notice Vault 地址列表
    address[] private _vaultList;
    
    // ============ 构造函数与初始化 ============
    
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }
    
    /**
     * @notice 初始化函数
     * @param _owner 合约所有者地址
     */
    function initialize(address _owner) external initializer {
        __Ownable_init(_owner);
        __UUPSUpgradeable_init();
        __Pausable_init();
        __ReentrancyGuard_init();
    }

    // ============ 管理员功能 ============
    
    /**
     * @notice 添加支持的 ERC4626 Vault
     * @param vaultAddress Vault 合约地址
     */
    function addVault(address vaultAddress) external onlyOwner {
        require(vaultAddress != address(0), "Invalid vault address");
        require(!supportedVaults[vaultAddress], "Vault already supported");
        
        // 验证是有效的 ERC4626 vault
        try IERC4626(vaultAddress).asset() returns (address) {
            // 成功调用，说明是有效的 ERC4626
        } catch {
            revert("Not a valid ERC4626 vault");
        }
        
        supportedVaults[vaultAddress] = true;
        _vaultList.push(vaultAddress);
    }
    
    /**
     * @notice 移除支持的 ERC4626 Vault
     * @param vaultAddress Vault 合约地址
     */
    function removeVault(address vaultAddress) external onlyOwner {
        require(supportedVaults[vaultAddress], "Vault not supported");
        
        supportedVaults[vaultAddress] = false;
        
        // 从列表中移除
        for (uint i = 0; i < _vaultList.length; i++) {
            if (_vaultList[i] == vaultAddress) {
                _vaultList[i] = _vaultList[_vaultList.length - 1];
                _vaultList.pop();
                break;
            }
        }
    }
    
    /**
     * @notice 获取所有支持的 vaults
     */
    function getSupportedVaults() external view returns (address[] memory) {
        return _vaultList;
    }
    
    /**
     * @notice 检查 vault 是否支持
     */
    function isVaultSupported(address vaultAddress) external view returns (bool) {
        return supportedVaults[vaultAddress];
    }

    // ============ IDefiAdapter 接口实现 ============
    
    /**
     * @notice 检查适配器是否支持指定的操作类型
     * @param operationType 操作类型
     * @return 是否支持
     */
    function supportsOperation(IOperationTypes.OperationType operationType) external pure override returns (bool) {
        return operationType == IOperationTypes.OperationType.VAULT_DEPOSIT ||
               operationType == IOperationTypes.OperationType.VAULT_MINT ||
               operationType == IOperationTypes.OperationType.VAULT_WITHDRAW ||
               operationType == IOperationTypes.OperationType.VAULT_REDEEM;
    }
    
    /**
     * @notice 执行 DeFi 操作
     * @param operationType 操作类型
     * @param params 操作参数
     * @param feeRateBps 手续费率（基点）
     * @return 操作结果
     */
    function executeOperation(
        IOperationTypes.OperationType operationType,
        IOperationTypes.OperationParams calldata params,
        uint24 feeRateBps
    ) external override whenNotPaused nonReentrant returns (IOperationTypes.OperationResult memory) {
        require(params.tokens.length >= 1, "Invalid tokens length");
        address vaultAddress = params.tokens[0];
        require(supportedVaults[vaultAddress], "Vault not supported");
        
        IERC4626 vault = IERC4626(vaultAddress);
        address asset = vault.asset();
        
        if (operationType == IOperationTypes.OperationType.VAULT_DEPOSIT) {
            return _executeDeposit(vault, asset, params, feeRateBps);
        } else if (operationType == IOperationTypes.OperationType.VAULT_MINT) {
            return _executeMint(vault, asset, params, feeRateBps);
        } else if (operationType == IOperationTypes.OperationType.VAULT_WITHDRAW) {
            return _executeWithdraw(vault, asset, params, feeRateBps);
        } else if (operationType == IOperationTypes.OperationType.VAULT_REDEEM) {
            return _executeRedeem(vault, asset, params, feeRateBps);
        } else {
            revert("Unsupported operation");
        }
    }
    
    /**
     * @notice 预估操作结果
     * @param operationType 操作类型
     * @param params 操作参数
     * @return 预估结果
     */
    function estimateOperation(
        IOperationTypes.OperationType operationType,
        IOperationTypes.OperationParams calldata params
    ) external view override returns (IOperationTypes.OperationResult memory) {
        require(params.tokens.length >= 1, "Invalid tokens length");
        address vaultAddress = params.tokens[0];
        require(supportedVaults[vaultAddress], "Vault not supported");
        
        IERC4626 vault = IERC4626(vaultAddress);
        
        if (operationType == IOperationTypes.OperationType.VAULT_DEPOSIT) {
            require(params.amounts.length >= 1, "Invalid amounts length");
            uint256 assets = params.amounts[0];
            uint256 shares = vault.previewDeposit(assets);
            uint256[] memory outputAmounts = new uint256[](2);
            outputAmounts[0] = assets;
            outputAmounts[1] = shares;
            return IOperationTypes.OperationResult({
                success: true,
                outputAmounts: outputAmounts,
                returnData: abi.encode(shares),
                message: "Deposit estimation"
            });
        } else if (operationType == IOperationTypes.OperationType.VAULT_MINT) {
            require(params.amounts.length >= 1, "Invalid amounts length");
            uint256 shares = params.amounts[0];
            uint256 assets = vault.previewMint(shares);
            uint256[] memory outputAmounts = new uint256[](2);
            outputAmounts[0] = shares;
            outputAmounts[1] = assets;
            return IOperationTypes.OperationResult({
                success: true,
                outputAmounts: outputAmounts,
                returnData: abi.encode(assets),
                message: "Mint estimation"
            });
        } else if (operationType == IOperationTypes.OperationType.VAULT_WITHDRAW) {
            require(params.amounts.length >= 1, "Invalid amounts length");
            uint256 assets = params.amounts[0];
            uint256 shares = vault.previewWithdraw(assets);
            uint256[] memory outputAmounts = new uint256[](2);
            outputAmounts[0] = assets;
            outputAmounts[1] = shares;
            return IOperationTypes.OperationResult({
                success: true,
                outputAmounts: outputAmounts,
                returnData: abi.encode(shares),
                message: "Withdraw estimation"
            });
        } else if (operationType == IOperationTypes.OperationType.VAULT_REDEEM) {
            require(params.amounts.length >= 1, "Invalid amounts length");
            uint256 shares = params.amounts[0];
            uint256 assets = vault.previewRedeem(shares);
            uint256[] memory outputAmounts = new uint256[](2);
            outputAmounts[0] = shares;
            outputAmounts[1] = assets;
            return IOperationTypes.OperationResult({
                success: true,
                outputAmounts: outputAmounts,
                returnData: abi.encode(assets),
                message: "Redeem estimation"
            });
        } else {
            uint256[] memory emptyAmounts = new uint256[](0);
            return IOperationTypes.OperationResult({
                success: false,
                outputAmounts: emptyAmounts,
                returnData: "",
                message: "Unsupported operation"
            });
        }
    }
    
    // ============ 内部执行函数 ============
    
    function _executeDeposit(
        IERC4626 vault,
        address asset,
        IOperationTypes.OperationParams calldata params,
        uint24 feeRateBps
    ) internal returns (IOperationTypes.OperationResult memory) {
        require(params.amounts.length >= 1, "Invalid amounts length");
        uint256 assets = params.amounts[0];
        address recipient = params.recipient == address(0) ? msg.sender : params.recipient;
        
        // 检查用户授权
        require(IERC20(asset).allowance(msg.sender, address(this)) >= assets, "Insufficient allowance");
        
        // 转入资产
        IERC20(asset).safeTransferFrom(msg.sender, address(this), assets);
        
        // 计算手续费
        uint256 fee = (assets * feeRateBps) / 10000;
        uint256 netAssets = assets - fee;
        
        // 如果有手续费，转给所有者
        if (fee > 0) {
            IERC20(asset).safeTransfer(owner(), fee);
        }
        
        // 授权 vault
        IERC20(asset).safeIncreaseAllowance(address(vault), netAssets);
        
        // 存款到 vault
        uint256 shares = vault.deposit(netAssets, recipient);
        
        emit VaultDeposit(msg.sender, address(vault), netAssets, shares, block.timestamp);
        
        uint256[] memory outputAmounts = new uint256[](2);
        outputAmounts[0] = netAssets;
        outputAmounts[1] = shares;
        return IOperationTypes.OperationResult({
            success: true,
            outputAmounts: outputAmounts,
            returnData: abi.encode(shares),
            message: "Deposit successful"
        });
    }
    
    function _executeMint(
        IERC4626 vault,
        address asset,
        IOperationTypes.OperationParams calldata params,
        uint24 feeRateBps
    ) internal returns (IOperationTypes.OperationResult memory) {
        require(params.amounts.length >= 1, "Invalid amounts length");
        uint256 shares = params.amounts[0];
        address recipient = params.recipient == address(0) ? msg.sender : params.recipient;
        
        // 预览需要的资产数量
        uint256 assets = vault.previewMint(shares);
        
        // 检查用户授权
        require(IERC20(asset).allowance(msg.sender, address(this)) >= assets, "Insufficient allowance");
        
        // 转入资产
        IERC20(asset).safeTransferFrom(msg.sender, address(this), assets);
        
        // 计算手续费
        uint256 fee = (assets * feeRateBps) / 10000;
        uint256 netAssets = assets - fee;
        
        // 如果有手续费，转给所有者
        if (fee > 0) {
            IERC20(asset).safeTransfer(owner(), fee);
        }
        
        // 重新计算需要的净资产数量（因为手续费后资产减少）
        uint256 adjustedShares = vault.previewDeposit(netAssets);
        
        // 授权 vault
        IERC20(asset).safeIncreaseAllowance(address(vault), netAssets);
        
        // 铸造份额
        uint256 actualShares = vault.mint(adjustedShares, recipient);
        
        emit VaultDeposit(msg.sender, address(vault), netAssets, actualShares, block.timestamp);
        
        uint256[] memory outputAmounts = new uint256[](2);
        outputAmounts[0] = actualShares;
        outputAmounts[1] = netAssets;
        return IOperationTypes.OperationResult({
            success: true,
            outputAmounts: outputAmounts,
            returnData: abi.encode(actualShares, netAssets),
            message: "Mint successful"
        });
    }
    
    function _executeWithdraw(
        IERC4626 vault,
        address asset,
        IOperationTypes.OperationParams calldata params,
        uint24 feeRateBps
    ) internal returns (IOperationTypes.OperationResult memory) {
        require(params.amounts.length >= 1, "Invalid amounts length");
        uint256 assets = params.amounts[0];
        address recipient = params.recipient == address(0) ? msg.sender : params.recipient;
        
        // 预览需要的份额数量
        uint256 shares = vault.previewWithdraw(assets);
        
        // 检查用户份额
        require(vault.balanceOf(msg.sender) >= shares, "Insufficient shares");
        
        // 从用户转入份额
        vault.transferFrom(msg.sender, address(this), shares);
        
        // 授权 vault 取款
        vault.approve(address(vault), shares);
        
        // 取款
        uint256 actualAssets = vault.withdraw(assets, recipient, address(this));
        
        // 计算手续费
        uint256 fee = (actualAssets * feeRateBps) / 10000;
        uint256 netAssets = actualAssets - fee;
        
        // 如果有手续费，转给所有者
        if (fee > 0) {
            IERC20(asset).safeTransfer(owner(), fee);
        }
        
        // 转出净资产给用户
        if (recipient != address(this)) {
            IERC20(asset).safeTransfer(recipient, netAssets);
        }
        
        emit VaultWithdraw(msg.sender, address(vault), shares, netAssets, block.timestamp);
        
        uint256[] memory outputAmounts = new uint256[](2);
        outputAmounts[0] = netAssets;
        outputAmounts[1] = shares;
        return IOperationTypes.OperationResult({
            success: true,
            outputAmounts: outputAmounts,
            returnData: abi.encode(netAssets, shares),
            message: "Withdraw successful"
        });
    }
    
    function _executeRedeem(
        IERC4626 vault,
        address asset,
        IOperationTypes.OperationParams calldata params,
        uint24 feeRateBps
    ) internal returns (IOperationTypes.OperationResult memory) {
        require(params.amounts.length >= 1, "Invalid amounts length");
        uint256 shares = params.amounts[0];
        address recipient = params.recipient == address(0) ? msg.sender : params.recipient;
        
        // 检查用户份额
        require(vault.balanceOf(msg.sender) >= shares, "Insufficient shares");
        
        // 从用户转入份额
        vault.transferFrom(msg.sender, address(this), shares);
        
        // 授权 vault 赎回
        vault.approve(address(vault), shares);
        
        // 赎回
        uint256 assets = vault.redeem(shares, address(this), address(this));
        
        // 计算手续费
        uint256 fee = (assets * feeRateBps) / 10000;
        uint256 netAssets = assets - fee;
        
        // 如果有手续费，转给所有者
        if (fee > 0) {
            IERC20(asset).safeTransfer(owner(), fee);
        }
        
        // 转出净资产给用户
        if (recipient != address(this)) {
            IERC20(asset).safeTransfer(recipient, netAssets);
        }
        
        emit VaultWithdraw(msg.sender, address(vault), shares, netAssets, block.timestamp);
        
        uint256[] memory outputAmounts = new uint256[](2);
        outputAmounts[0] = shares;
        outputAmounts[1] = netAssets;
        return IOperationTypes.OperationResult({
            success: true,
            outputAmounts: outputAmounts,
            returnData: abi.encode(shares, netAssets),
            message: "Redeem successful"
        });
    }
    
    // ============ 升级相关 ============
    
    /**
     * @dev UUPS升级授权
     */
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}