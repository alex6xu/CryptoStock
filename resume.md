

- 项目一:链上股票代币化与交易系统 MetaTower Technologies PTE. LTD. 2024.9-2026.3 
- 技术栈:Solidity 0.8.20、 Hardhat. OpenZeppelin Upgrades (UUPS)、 chainlink + Pyth + RedStone. 多预言机加权、Ethers.jsv6
项目背景：将中心化证券市场的股票资产抽象为链上代币，解决传统股票交易时间受限、跨境门高、清算慢的问题。目标：支持可扩属股票代币发行、可信价格聚合、USDT直接买卖、合约可升级与安全治理。
职责
设计并实现股票代币和工厂合约
构建多预言机加权聚合器 PriceAggregator (Pyth + RedStone　＋ Chainlink) 
在代币合约内直接集成买入/卖出，实现：滑点保护、最小交易额、手续费
安全机制:ReentrancyGuard, Upgradeable, PausableUpgradeable,升级授权。
编写部署产物标准化输出，驱动的端与运维脚本。

主要贡献：
Mock 预言机与资产，模拟价格缺失、极端波动、失效路径。
聚合价格结构 OperationResult标准化
预言机获取失败处理机制，确保有效价格集>0
合约升级存储布同对比+回归测试确保零破坏。



项目二:多协议DeFI聚合项目 Aetherlum Labs Pte. Ltd, 2023.5-2024.8
技术：Solidity, Harhat, UUPS. SafeERC20, Ethers.js Aave/Compound/Curve/Unlswap V3/Pancakeswap/Yeam V3,适配著模式

项目背景:构建统一的 DeFi 协议适配层，聚合 Aave、Compound、Curve、UniswapV3、Pancake、YearnV3 等主流协议，实现资金跨协议流动与收益策略
我的职责：
 设计协议抽象层:OperationTypes+IDefiAdapler,构建统提作语义，
 实现5个适配：Aave/ Campound /Curve/ Uniswap V3/ Pancakeswap. 
 实现后端相关功能后端（StockCoinEnd）
- 链上事件监听（空投、收益回调）
- 任务调度、checkpoint 持久化
- REST API 与配置管理
主要贡献：
1. **多协议统一适配**：抽象 IDefiAdapter 接口，短期内对接 6 大 DeFi 协议，处理资产精度、利率模型、LP 份额等差异


项目三： 基于Merkle证明的批量空投项目
项目背景：一套基于Merkle证明空投系统，支持多批次、链上事件监听与后端任务调度。

职责：
负责空投合约的设计与开发工作，保证合约开发的
合约测试：
后端相关功能开发：
贡献：
优化空投功能的设计，有效减少撸空投的发生
增加合约批量空投功能，优化合约gas费
优化合约安全机制：增加黑名单功能，设置阶段式的merkleroot证明，防止恶意空投地址
