const { ethers, upgrades } = require("hardhat");
const fs = require("fs");
const path = require("path");

/**
 * 部署 ERC4626 适配器脚本
 * 使用方法: npx hardhat run scripts/deploy-erc4626-adapter-only.js --network <network>
 */

async function main() {
  console.log("🚀 开始部署 ERC4626 适配器...");

  // 获取部署者账户
  const [deployer] = await ethers.getSigners();
  console.log("📋 部署者地址:", deployer.address);

  // 显示账户余额
  const balance = await ethers.provider.getBalance(deployer.address);
  console.log("💰 账户余额:", ethers.formatEther(balance), "ETH");

  // 部署 ERC4626Adapter
  console.log("\n🏗️ 部署 ERC4626Adapter...");
  const ERC4626Adapter = await ethers.getContractFactory("ERC4626Adapter");
  const erc4626Adapter = await upgrades.deployProxy(
    ERC4626Adapter,
    [deployer.address], // owner
    {
      initializer: "initialize",
      kind: "uups"
    }
  );

  await erc4626Adapter.waitForDeployment();
  const erc4626AdapterAddress = await erc4626Adapter.getAddress();

  console.log("✅ ERC4626Adapter 部署成功:", erc4626AdapterAddress);

  // 提取ABI
  console.log("\n🔧 提取ABI文件...");
  const abiDir = path.join(__dirname, '..', 'abi');
  if (!fs.existsSync(abiDir)) {
    fs.mkdirSync(abiDir, { recursive: true });
  }

  // 提取 ERC4626Adapter ABI
  const artifactPath = path.join(
    __dirname,
    '..',
    'artifacts',
    'contracts',
    'adapters',
    'ERC4626Adapter.sol',
    'ERC4626Adapter.json'
  );

  if (fs.existsSync(artifactPath)) {
    const artifact = JSON.parse(fs.readFileSync(artifactPath, 'utf8'));
    const abiPath = path.join(abiDir, 'ERC4626Adapter.abi');
    fs.writeFileSync(abiPath, JSON.stringify(artifact.abi, null, 2));
    console.log("✅ ERC4626Adapter ABI 已保存到:", abiPath);
  }

  // 保存部署信息
  const deploymentInfo = {
    network: network.name,
    erc4626Adapter: erc4626AdapterAddress,
    deployer: deployer.address,
    timestamp: new Date().toISOString()
  };

  const deploymentPath = path.join(__dirname, '..', 'deployments-erc4626-adapter-sepolia.json');
  fs.writeFileSync(deploymentPath, JSON.stringify(deploymentInfo, null, 2));
  console.log("✅ 部署信息已保存到:", deploymentPath);

  console.log("\n🎉 ERC4626 适配器部署完成！");
  console.log("📋 部署摘要:");
  console.log("   ERC4626Adapter:", erc4626AdapterAddress);
}

// 处理错误
main().catch((error) => {
  console.error("❌ 部署失败:", error);
  process.exitCode = 1;
});