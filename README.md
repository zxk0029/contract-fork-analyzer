# Contract Fork Analyzer

一个用于分析和比较不同 DEX 合约的工具。

## 项目结构

```
src/
├── interfaces/      # 接口定义
│   └── IDEX.sol    # 通用 DEX 接口
```

## 依赖

- OpenZeppelin Contracts: 用于基础合约和接口
- Foundry: 开发和测试框架

## 安装

1. 首先安装 [Foundry](https://book.getfoundry.sh/getting-started/installation)

2. 克隆项目并安装依赖：
```shell
git clone <your-repo-url>
cd contract-fork-analyzer
forge install
```

3. 配置环境变量：
```shell
cp .env.example .env
```
然后编辑 `.env` 文件，填入你的实际配置：
- RPC URLs：各链的 RPC 节点地址
- API Keys：各链的区块浏览器 API 密钥
- Analysis Config：分析配置（目标代币、DEX 等）

## 使用说明

### 本地开发

启动分叉节点：
```shell
# 从特定区块高度分叉主网
anvil --fork-url $BSC_RPC_URL --block-number 123456

# 从最新区块分叉主网
anvil --fork-url $BSC_RPC_URL
```

### 编译

```shell
forge build
```

### 测试

```shell
forge test
```

### 格式化代码

```shell
forge fmt
```

### Gas 分析

```shell
forge snapshot
```

## 接口说明

项目定义了一套通用的 DEX 接口，包括：

- `IDEXFactory`: DEX 工厂合约接口
- `IDEXPair`: DEX 交易对合约接口
- `IDEXRouter`: DEX 路由合约接口

这些接口可以用于适配不同的 DEX 实现（如 Uniswap、PancakeSwap 等）。

## 配置

项目使用 `foundry.toml` 进行配置，主要包括：

- Solidity 版本：0.8.20
- 优化器设置
- 依赖映射
- RPC 端点配置
- Etherscan API 配置

### 环境变量

项目使用以下环境变量：

```shell
# RPC URLs
ETH_RPC_URL=your_ethereum_rpc_url
BSC_RPC_URL=your_bsc_rpc_url
ARB_RPC_URL=your_arbitrum_rpc_url

# API Keys
ETHERSCAN_KEY=your_etherscan_key
ARBISCAN_KEY=your_arbiscan_key
BSCSCAN_KEY=your_bscscan_key

# Analysis Config
TARGET_TOKEN=   # 目标代币地址
BASE_TOKEN=     # 基础代币地址（如 USDT）
DEX_NAME=       # DEX 名称
CHAIN_ID=       # 链 ID
```

## License

MIT
