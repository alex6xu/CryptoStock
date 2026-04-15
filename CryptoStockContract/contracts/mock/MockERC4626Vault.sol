// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/interfaces/IERC4626.sol";

/**
 * @title MockERC4626Vault
 * @notice Mock ERC4626 Vault for testing
 * @dev Simple ERC4626 implementation for testing purposes
 */
contract MockERC4626Vault is ERC20, IERC4626 {
    using SafeERC20 for IERC20;

    IERC20 private immutable _underlying;
    uint8 private immutable _decimals;

    // Simple yield simulation
    uint256 public constant YIELD_RATE = 100; // 1% per deposit (simplified)
    mapping(address => uint256) public userDepositTime;

    constructor(
        address underlying_,
        string memory name_,
        string memory symbol_
    ) ERC20(name_, symbol_) {
        _underlying = IERC20(underlying_);
        _decimals = ERC20(underlying_).decimals();
    }

    function asset() external view returns (address) {
        return address(_underlying);
    }

    function totalAssets() external view returns (uint256) {
        return _underlying.balanceOf(address(this));
    }

    function convertToShares(uint256 assets) external view returns (uint256) {
        uint256 supply = totalSupply();
        return supply == 0 ? assets : (assets * supply) / this.totalAssets();
    }

    function convertToAssets(uint256 shares) external view returns (uint256) {
        uint256 supply = totalSupply();
        return supply == 0 ? shares : (shares * this.totalAssets()) / supply;
    }

    function maxDeposit(address) external pure returns (uint256) {
        return type(uint256).max;
    }

    function maxMint(address) external pure returns (uint256) {
        return type(uint256).max;
    }

    function maxWithdraw(address owner) external view returns (uint256) {
        return convertToAssets(balanceOf(owner));
    }

    function maxRedeem(address owner) external view returns (uint256) {
        return balanceOf(owner);
    }

    function previewDeposit(uint256 assets) external view returns (uint256) {
        return convertToShares(assets);
    }

    function previewMint(uint256 shares) external view returns (uint256) {
        uint256 supply = totalSupply();
        return supply == 0 ? shares : (shares * this.totalAssets()) / supply;
    }

    function previewWithdraw(uint256 assets) external view returns (uint256) {
        return convertToShares(assets);
    }

    function previewRedeem(uint256 shares) external view returns (uint256) {
        return convertToAssets(shares);
    }

    function deposit(uint256 assets, address receiver) external returns (uint256) {
        require(assets > 0, "Cannot deposit 0");

        uint256 shares = previewDeposit(assets);

        _underlying.safeTransferFrom(msg.sender, address(this), assets);
        _mint(receiver, shares);

        userDepositTime[receiver] = block.timestamp;

        return shares;
    }

    function mint(uint256 shares, address receiver) external returns (uint256) {
        require(shares > 0, "Cannot mint 0");

        uint256 assets = previewMint(shares);

        _underlying.safeTransferFrom(msg.sender, address(this), assets);
        _mint(receiver, shares);

        userDepositTime[receiver] = block.timestamp;

        return assets;
    }

    function withdraw(uint256 assets, address receiver, address owner) external returns (uint256) {
        require(assets > 0, "Cannot withdraw 0");

        uint256 shares = previewWithdraw(assets);

        if (msg.sender != owner) {
            _spendAllowance(owner, msg.sender, shares);
        }

        _burn(owner, shares);
        _underlying.safeTransfer(receiver, assets);

        return shares;
    }

    function redeem(uint256 shares, address receiver, address owner) external returns (uint256) {
        require(shares > 0, "Cannot redeem 0");

        uint256 assets = previewRedeem(shares);

        if (msg.sender != owner) {
            _spendAllowance(owner, msg.sender, shares);
        }

        _burn(owner, shares);
        _underlying.safeTransfer(receiver, assets);

        return assets;
    }

    function decimals() public view override returns (uint8) {
        return _decimals;
    }
}