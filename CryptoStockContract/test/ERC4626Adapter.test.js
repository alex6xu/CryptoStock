const { expect } = require("chai");
const { ethers, upgrades } = require("hardhat");

describe("ERC4626Adapter", function () {
  let erc4626Adapter;
  let mockERC20;
  let mockVault;
  let owner;
  let user;
  let feeRecipient;

  const INITIAL_SUPPLY = ethers.parseEther("1000000");
  const DEPOSIT_AMOUNT = ethers.parseEther("1000");

  beforeEach(async function () {
    [owner, user, feeRecipient] = await ethers.getSigners();

    // 部署 MockERC20
    const MockERC20 = await ethers.getContractFactory("MockERC20");
    mockERC20 = await MockERC20.deploy("Mock Token", "MOCK", INITIAL_SUPPLY);
    await mockERC20.waitForDeployment();

    // 部署 MockERC4626Vault
    const MockERC4626Vault = await ethers.getContractFactory("MockERC4626Vault");
    mockVault = await MockERC4626Vault.deploy(await mockERC20.getAddress(), "Mock Vault", "MV");
    await mockVault.waitForDeployment();

    // 部署 ERC4626Adapter
    const ERC4626Adapter = await ethers.getContractFactory("ERC4626Adapter");
    erc4626Adapter = await upgrades.deployProxy(
      ERC4626Adapter,
      [owner.address],
      { initializer: "initialize", kind: "uups" }
    );
    await erc4626Adapter.waitForDeployment();

    // 添加支持的 vault
    await erc4626Adapter.addVault(await mockVault.getAddress());

    // 给用户一些代币
    await mockERC20.transfer(user.address, ethers.parseEther("10000"));
  });

  describe("Deployment", function () {
    it("Should set the right owner", async function () {
      expect(await erc4626Adapter.owner()).to.equal(owner.address);
    });

    it("Should support the added vault", async function () {
      expect(await erc4626Adapter.isVaultSupported(await mockVault.getAddress())).to.be.true;
    });
  });

  describe("Operations", function () {
    beforeEach(async function () {
      // 用户授权适配器
      await mockERC20.connect(user).approve(await erc4626Adapter.getAddress(), ethers.MaxUint256);
    });

    it("Should execute deposit operation", async function () {
      const params = {
        tokens: [await mockVault.getAddress()],
        amounts: [DEPOSIT_AMOUNT],
        recipient: user.address,
        deadline: 0,
        tokenId: 0,
        extraData: "0x"
      };

      const result = await erc4626Adapter.connect(user).executeOperation(
        21, // VAULT_DEPOSIT
        params,
        0 // 0 fee for simplicity
      );

      expect(result.success).to.be.true;
      expect(result.outputAmounts.length).to.equal(2);
    });

    it("Should estimate deposit operation", async function () {
      const params = {
        tokens: [await mockVault.getAddress()],
        amounts: [DEPOSIT_AMOUNT],
        recipient: user.address,
        deadline: 0,
        tokenId: 0,
        extraData: "0x"
      };

      const result = await erc4626Adapter.estimateOperation(21, params); // VAULT_DEPOSIT

      expect(result.success).to.be.true;
      expect(result.message).to.equal("Deposit estimation");
    });

    it("Should execute mint operation", async function () {
      const sharesAmount = ethers.parseEther("100");
      const params = {
        tokens: [await mockVault.getAddress()],
        amounts: [sharesAmount],
        recipient: user.address,
        deadline: 0,
        tokenId: 0,
        extraData: "0x"
      };

      const result = await erc4626Adapter.connect(user).executeOperation(
        22, // VAULT_MINT
        params,
        0
      );

      expect(result.success).to.be.true;
    });

    it("Should execute withdraw operation", async function () {
      // 先存款
      await mockERC20.connect(user).approve(await mockVault.getAddress(), DEPOSIT_AMOUNT);
      await mockVault.connect(user).deposit(DEPOSIT_AMOUNT, user.address);

      const params = {
        tokens: [await mockVault.getAddress()],
        amounts: [DEPOSIT_AMOUNT / 2n], // 取款一半
        recipient: user.address,
        deadline: 0,
        tokenId: 0,
        extraData: "0x"
      };

      const result = await erc4626Adapter.connect(user).executeOperation(
        23, // VAULT_WITHDRAW
        params,
        0
      );

      expect(result.success).to.be.true;
    });

    it("Should execute redeem operation", async function () {
      // 先存款
      await mockERC20.connect(user).approve(await mockVault.getAddress(), DEPOSIT_AMOUNT);
      await mockVault.connect(user).deposit(DEPOSIT_AMOUNT, user.address);

      const userShares = await mockVault.balanceOf(user.address);
      const params = {
        tokens: [await mockVault.getAddress()],
        amounts: [userShares / 2n], // 赎回一半份额
        recipient: user.address,
        deadline: 0,
        tokenId: 0,
        extraData: "0x"
      };

      const result = await erc4626Adapter.connect(user).executeOperation(
        24, // VAULT_REDEEM
        params,
        0
      );

      expect(result.success).to.be.true;
    });
  });

  describe("Fee handling", function () {
    it("Should charge fees on deposit", async function () {
      const feeRate = 100; // 1%
      await erc4626Adapter.setFeeRate(feeRate);

      const params = {
        tokens: [await mockVault.getAddress()],
        amounts: [DEPOSIT_AMOUNT],
        recipient: user.address,
        deadline: 0,
        tokenId: 0,
        extraData: "0x"
      };

      const initialOwnerBalance = await mockERC20.balanceOf(owner.address);

      await erc4626Adapter.connect(user).executeOperation(21, params, feeRate);

      const finalOwnerBalance = await mockERC20.balanceOf(owner.address);
      const expectedFee = (DEPOSIT_AMOUNT * BigInt(feeRate)) / 10000n;

      expect(finalOwnerBalance - initialOwnerBalance).to.equal(expectedFee);
    });
  });

  describe("Access control", function () {
    it("Should only allow owner to add/remove vaults", async function () {
      const newVault = ethers.Wallet.createRandom().address;

      await expect(
        erc4626Adapter.connect(user).addVault(newVault)
      ).to.be.revertedWith("Ownable: caller is not the owner");

      await expect(
        erc4626Adapter.connect(user).removeVault(await mockVault.getAddress())
      ).to.be.revertedWith("Ownable: caller is not the owner");
    });
  });
});