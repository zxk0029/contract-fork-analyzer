# Foundry Fork 模拟测试方案

## 概述
本文档详细说明如何使用 Foundry 的 fork 功能进行合约手续费分析。通过 fork 主网状态，我们可以在本地环境中精确模拟和分析合约的交易行为，包括：
- 买入/卖出手续费计算
- 转账费用验证
- Gas 消耗分析
- 交易路径验证

## 前置条件
- 已安装 Foundry（forge、cast、anvil）
- 目标链的 RPC URL（支持 archive 节点）
- 相关 API Key（用于合约验证）
- 足够的计算资源（fork 测试需要较大内存）

## 实现步骤

### 1. 项目初始化
```bash
# 创建新项目
forge init contract-fork-analyzer
cd contract-fork-analyzer

# 安装依赖
forge install OpenZeppelin/openzeppelin-contracts
```

### 2. 项目结构
```
contract-fork-analyzer/
├── .env                    # 环境变量（RPC URL等）
├── .gitignore
├── foundry.toml           # Foundry 配置
├── lib/                   # 依赖库
├── script/               # 部署脚本
│   └── DeployTest.s.sol
├── src/                  # 合约源码
│   └── interfaces/      # 接口定义
│       ├── IERC20.sol
│       └── IUniswapV2Router02.sol
└── test/                # 测试文件
    └── FeeTest.t.sol   # 手续费测试
```

### 3. 环境配置
```toml
# foundry.toml
[profile.default]
src = "src"
out = "out"
libs = ["lib"]
solc = "0.8.20"
optimizer = true
optimizer_runs = 200

[rpc_endpoints]
mainnet = "${ETH_RPC_URL}"
arbitrum = "${ARB_RPC_URL}"
bsc = "${BSC_RPC_URL}"

[etherscan]
mainnet = { key = "${ETHERSCAN_KEY}" }
arbitrum = { key = "${ARBISCAN_KEY}" }
bsc = { key = "${BSCSCAN_KEY}" }
```

### 4. 接口定义
```solidity
// src/interfaces/IERC20.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
}

// src/interfaces/IUniswapV2Router02.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IUniswapV2Router02 {
    function getAmountsOut(uint256 amountIn, address[] calldata path) external view returns (uint256[] memory amounts);
    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);
}
```

### 5. 测试合约实现
```solidity
// test/FeeTest.t.sol
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/interfaces/IERC20.sol";
import "../src/interfaces/IUniswapV2Router02.sol";

contract FeeTest is Test {
    // 目标合约地址
    address constant TARGET = 0xBF6Cd8D57ffe3CBe3D78DEd8DA34345A3B736102;
    // DEX 路由地址（根据实际链和 DEX 设置）
    address constant ROUTER = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
    // 原生代币包装合约（如 WETH）
    address constant WRAPPED = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    
    IERC20 token;
    IUniswapV2Router02 router;
    
    function setUp() public {
        // fork 设置
        vm.createSelectFork(vm.rpcUrl("mainnet"));
        
        // 初始化合约
        token = IERC20(TARGET);
        router = IUniswapV2Router02(ROUTER);
        
        // 准备测试账户
        deal(address(this), 100 ether);
        deal(WRAPPED, address(this), 100 ether);
    }
    
    function testBuyTax() public {
        // 买入前余额
        uint256 balanceBefore = token.balanceOf(address(this));
        
        // 准备买入参数
        address[] memory path = new address[](2);
        path[0] = WRAPPED;
        path[1] = TARGET;
        
        // 授权
        IERC20(WRAPPED).approve(ROUTER, type(uint256).max);
        
        // 执行买入
        uint256 amountIn = 1 ether;
        uint256[] memory amounts = router.getAmountsOut(amountIn, path);
        uint256 expectedOut = amounts[1];
        
        router.swapExactTokensForTokens(
            amountIn,
            0, // 接受任意数量
            path,
            address(this),
            block.timestamp
        );
        
        // 验证买入税
        uint256 balanceAfter = token.balanceOf(address(this));
        uint256 actualReceived = balanceAfter - balanceBefore;
        uint256 buyTaxBps = (expectedOut - actualReceived) * 10000 / expectedOut;
        
        console.log("Expected amount:", expectedOut);
        console.log("Actual received:", actualReceived);
        console.log("Buy tax (bps):", buyTaxBps);
        
        // 假设预期买入税为 3%
        assertApproxEqRel(buyTaxBps, 300, 10); // 允许 0.1% 误差
    }
    
    function testSellTax() public {
        // 先买入一些代币
        testBuyTax();
        
        // 准备卖出参数
        address[] memory path = new address[](2);
        path[0] = TARGET;
        path[1] = WRAPPED;
        
        // 记录卖出前余额
        uint256 balanceBefore = IERC20(WRAPPED).balanceOf(address(this));
        uint256 tokenAmount = token.balanceOf(address(this));
        
        // 授权
        token.approve(ROUTER, type(uint256).max);
        
        // 获取预期输出
        uint256[] memory amounts = router.getAmountsOut(tokenAmount, path);
        uint256 expectedOut = amounts[1];
        
        // 执行卖出
        router.swapExactTokensForTokens(
            tokenAmount,
            0,
            path,
            address(this),
            block.timestamp
        );
        
        // 验证卖出税
        uint256 balanceAfter = IERC20(WRAPPED).balanceOf(address(this));
        uint256 actualReceived = balanceAfter - balanceBefore;
        uint256 sellTaxBps = (expectedOut - actualReceived) * 10000 / expectedOut;
        
        console.log("Expected amount:", expectedOut);
        console.log("Actual received:", actualReceived);
        console.log("Sell tax (bps):", sellTaxBps);
        
        // 假设预期卖出税为 3%
        assertApproxEqRel(sellTaxBps, 300, 10); // 允许 0.1% 误差
    }
    
    function testTransferTax() public {
        // 先买入一些代币
        testBuyTax();
        
        // 记录转账前余额
        uint256 amount = token.balanceOf(address(this));
        address recipient = address(0xdead);
        
        // 执行转账
        token.transfer(recipient, amount);
        
        // 验证转账税
        uint256 recipientBalance = token.balanceOf(recipient);
        uint256 transferTaxBps = (amount - recipientBalance) * 10000 / amount;
        
        console.log("Transfer amount:", amount);
        console.log("Recipient received:", recipientBalance);
        console.log("Transfer tax (bps):", transferTaxBps);
        
        // 假设预期转账税为 0%
        assertApproxEqRel(transferTaxBps, 0, 10); // 允许 0.1% 误差
    }
}
```

### 6. 执行测试
```bash
# 运行所有测试
forge test -vvv

# 运行单个测试
forge test --match-test testBuyTax -vvv
forge test --match-test testSellTax -vvv
forge test --match-test testTransferTax -vvv
```

### 7. 测试结果分析
- 检查输出的税费数据
- 验证是否符合 TokenSniffer 和 Honeypot.is 的分析结果
- 记录任何异常情况
- 对比不同 DEX 的结果（如果需要）

## 注意事项
1. RPC 配置
   - 使用可靠的 RPC 节点
   - 注意 RPC 的请求限制
   - 建议使用私有节点

2. 测试环境
   - 选择合适的 fork 区块
   - 确保环境变量正确配置
   - 注意测试的幂等性

3. 安全考虑
   - 不要在代码中硬编码 API Key
   - 使用 .env 文件管理敏感信息
   - 注意测试环境的隔离

## 常见问题
1. RPC 连接问题
   - 检查 RPC URL 是否正确
   - 确认网络连接状态
   - 验证 API Key 是否有效

2. 测试失败处理
   - 检查预期值是否正确
   - 确认合约状态
   - 验证交易路径

3. Gas 相关问题
   - 调整 gas 限制
   - 检查 gas 估算
   - 确认余额充足

## 更新记录
- 2024-03-20：创建文档
- 2024-03-20：添加接口定义
- 2024-03-20：完善测试用例 