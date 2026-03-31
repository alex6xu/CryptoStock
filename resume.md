## 个人信息

- **姓名**：alex
- **求职方向**：智能合约开发（Solidity）
- **学历**：硕士（计算机软件工程）
- **邮箱**：alexuhui122@gmail.com

## 技术能力

- **智能合约**：Solidity（0.8.x）、Hardhat、Ethers.js v6、OpenZeppelin（UUPS/Upgradeable、Ownable/AccessControl、SafeERC20、ReentrancyGuard、Pausable）
- **安全与工程化**：权限与升级治理、回归测试、存储布局检查（升级安全）、部署脚本与产物标准化输出
- **预言机与价格体系**：Chainlink / Pyth / RedStone；多源聚合、精度标准化、时间戳与有效性校验、异常与失效降级
- **Golang后端**：Go（链上事件监听、任务调度、checkpoint 持久化、REST API、配置管理）
- **多预言机价格聚合**：使用接口统一输入与返回数据结构，处理精度与时间戳对齐，并在数据源异常时做降级与失败隔离
- **可升级与治理**：UUPS 升级授权控制 + 存储布局对比/回归验证，降低升级带来的破坏性变更风险
- **资金安全**：买卖/结算路径加入滑点保护、最小交易额与手续费模型，并配套重入与暂停保护

## 项目经历

### 链上股票代币化与交易系统｜MetaTower Technologies PTE. LTD.｜2024.09–2026.03

- **项目概述**：将中心化证券市场的股票资产抽象为链上代币，提供可信价格聚合与以 USDT 计价的链上买卖能力；支持合约可升级与安全治理。
- **技术栈**：Solidity 0.8.20、Hardhat、OpenZeppelin Upgrades（UUPS）、Chainlink + Pyth + RedStone、Ethers.js v6
- **工作内容**：
  - 设计并实现股票代币合约与工厂合约（发行/配置/权限治理等核心流程）
  - 构建多预言机加权聚合器 `PriceAggregator`（Pyth/RedStone/Chainlink），实现价格精度标准化、时间戳对齐与有效性校验
  - 在代币合约内集成买入/卖出与结算逻辑，支持滑点保护、最小交易额、手续费计算，并完善失败回滚与异常处理
  - 落地安全机制：UUPS 升级授权控制、`ReentrancyGuard`、`PausableUpgradeable` 等关键保护
  - 编写部署与运维脚本，规范化部署产物输出，降低交付与运维成本
- **关键产出**：
  - 自研 Mock 预言机/资产用例，覆盖价格缺失、极端波动、数据过期等失效路径，提升回归测试完整性
  - 设计预言机失败处理与降级策略，确保在部分数据源异常时仍能得到可用的有效价格集合
  - 针对合约升级，做存储布局对比与回归验证，降低升级引入破坏性变更的风险

### 多协议 DeFi 聚合｜Aetherlum Labs Pte. Ltd.｜2023.05–2024.08

- **项目概述**：构建统一的 DeFi 协议适配层，聚合 Aave、Compound、Curve、Uniswap V3、Pancake 等协议，实现资金跨协议流动与收益策略编排。
- **技术栈**：Solidity、Hardhat、UUPS、OpenZeppelin（SafeERC20）、Ethers.js；Aave/Compound/Curve/Uniswap V3/PancakeSwap（等）
- **工作内容**：
  - 设计协议抽象层（如 `OperationTypes` + `IDefiAdapter`），将跨协议操作统一为可组合的语义与参数模型
  - 实现并维护多协议适配器（Aave / Compound / Curve / Uniswap V3 / PancakeSwap 等），处理资产精度、利率模型、LP 份额与兑换路径差异
  - 配套后端能力：链上事件监听、任务调度与 checkpoint 持久化、REST API 与配置管理
- **关键产出**：
  - 建立统一适配接口与错误处理规范，提升新协议接入效率与可维护性

### 基于 Merkle 证明的批量空投系统｜（项目）

- **项目概述**：基于 Merkle 证明的空投系统，支持多批次发放、链上事件监听与后端任务调度。
- **工作内容**：
  - 负责空投合约设计与开发，并编写合约测试用例覆盖领取、校验、异常路径等核心流程
  - 支持批量空投/分批次管理，优化领取与发放过程的 gas 成本
  - 完善安全机制：黑名单控制、阶段式 Merkle Root 管理，减少恶意地址与异常领取风险
