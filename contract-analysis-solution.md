# 合约分析解决方案

## 实现说明
本项目采用方案A实现，主要使用 TokenSniffer + Honeypot.is 进行分析，并使用 Foundry 进行本地验证测试。选择该方案的原因：
1. 目标合约部署在主流 EVM 链上，可以充分利用这些工具的优势
2. Foundry 的 fork 测试性能最好，且支持完整的测试场景
3. 可以通过 TokenSniffer 和 Honeypot.is 的交叉验证提高分析准确性

> Foundry 具体实现方案请参考 [foundry-implementation.md](./foundry-implementation.md)

## 项目背景
需要对已部署的合约（如：0xBF6Cd8D57ffe3CBe3D78DEd8DA34345A3B736102）进行分析和测试，但本地没有合约代码。需要：
1. 确定合约所在的链
2. 获取合约代码
3. 分析合约功能（特别是买卖手续费）
4. 本地模拟测试

## 工具评估

### 1. 跨链查询工具

#### TokenSniffer
- 网址：https://tokensniffer.com
- 功能：智能合约安全分析和代币审计工具
- 支持链：支持主要 EVM 兼容链
- 优点：
  - 提供代币安全评分（0-100分制）
  - 自动检测合约潜在风险
  - 显示买卖手续费信息
  - 提供合约部署信息和链接。如果开源，可以直接查看合约代码
  - 集成了 honeypot.is 的分析结果
- 限制：
  - 部分功能需要付费
  - 自动扫描可能存在误报
  - 评分仅供参考，不能完全依赖
- 适用场景：
  - 快速评估代币合约安全性
  - 检查代币买卖手续费
  - 验证合约是否为蜜罐（honeypot）
- 注意事项：
  - 高分代币仍可能存在隐藏的恶意代码
  - 建议结合其他工具综合分析
  - 结果每15分钟更新一次

#### Honeypot.is
- 网址：https://honeypot.is
- 功能：智能合约交易模拟和安全分析工具
- 支持链：
  - Ethereum（以太坊主网）
  - Binance Smart Chain（BSC）
  - Base
- 优点：
  - 提供详细的模拟交易结果
  - 显示具体的 gas 费用数据
  - 详细的税费分析（买入、卖出、转账）
  - 持有者分析功能
  - 直观的风险评估（如 "LOW RISK OF HONEYPOT"）
  - 支持多个 DEX 平台分析
- 详细数据：
  - 交易税费：
    - 买入税：精确到小数点
    - 卖出税：精确到小数点
    - 转账税：是否存在
  - Gas 分析：
    - 买入 gas 消耗
    - 卖出 gas 消耗
  - 持有者分析：
    - 持有者数量统计
    - 可卖出/不可卖出分析
    - 平均交易税费
    - 最高交易税费
- 限制：
  - 仅支持三条主要链（ETH、BSC、Base）
  - 其他链上的合约无法分析
  - 结果仅供参考，市场情况可能随时变化
  - 建议与其他工具结合使用
- 适用场景：
  - 交易前的合约安全检查
  - 详细的交易成本评估
  - 识别潜在的蜜罐合约
  - 分析持有者交易情况
- 注意事项：
  - 结果仅供参考，市场情况可能随时变化
  - 建议与其他工具结合使用
  - 需要注意 "THIS CAN ALWAYS CHANGE! DO YOUR OWN DUE DILIGENCE" 的警告

#### Oklink
- 网址：https://www.oklink.com
- 功能：跨链浏览器
- 优点：
  - 支持多链搜索
  - 界面友好
- 限制：
  - 合约未验证
  - 需跳转到对应区块浏览器查看源码
- 适用场景：快速跨链查询，但需配合其他工具使用

#### Blockscan
- 网址：https://blockscan.com
- 功能：跨链搜索工具，由 Etherscan 团队开发
- 优点：
  - 可以在 Transactions 标签中查看交易记录
  - 可以通过交易记录判断合约所在链
  - 支持多个 EVM 兼容链
- 适用场景：快速确定合约所在链和交易历史

#### DexScreener
- 网址：https://dexscreener.com
- 功能：DEX 交易对和代币信息查询
- 限制：
  - 仅显示已部署流动性的代币
  - 主要用于价格和交易数据分析
- 适用场景：分析已上线 DEX 的代币


## 解决方案流程

1. 定位合约所在链
   - 使用跨链查询工具（按优先级）：
     1. TokenSniffer（支持主要 EVM 链）
     2. Oklink（支持更多链）
     3. Blockscan（支持所有 EVM 链）
   - 确认合约所在链
   - 记录合约基本信息（部署时间、创建者等）

2. 分析合约交易费用
   方案A - 支持 Honeypot.is 的链（ETH、BSC、Base）：
   - 使用 TokenSniffer 和 Honeypot.is 进行交叉验证
   - 记录费用信息和 gas 消耗

   方案B - 其他 EVM 链：
   - 使用 TokenSniffer 进行初步分析
   - 通过区块浏览器验证合约代码
   - 分析历史交易记录确认实际费用

3. 获取合约详细信息（根据需求选择）
   - 如果合约已验证：
     - 直接从区块浏览器获取源码和 ABI
     - 分析合约功能和参数
   - 如果合约未验证：
     - 尝试反编译字节码
     - 分析历史交易记录
     - 使用工具链（如 Dedaub）分析

4. 本地测试环境搭建
   - 选择测试工具（按推荐顺序）：
     1. Foundry（推荐）
        - fork 测试支持最好
        - 执行速度快
        - 原生支持作弊码（cheatcodes）
        - 内置 anvil 节点，支持本地模拟
     
     2. Tenderly（在线模拟）
        - https://dashboard.tenderly.co/
        - 可视化交易模拟
        - 支持多链 fork
        - 实时调试能力
        - 无需本地环境
        - Web 界面操作友好
     
     3. Hardhat（备选）
        - https://hardhat.org/hardhat-network/docs/guides/forking-other-networks
        - JavaScript/TypeScript 生态
        - fork 功能较慢
        - 插件生态丰富
        - 支持 Solidity 和 Vyper  

        > Ganache已经archived，不建议使用  

5. 模拟测试方案

   方案A - Foundry Fork 测试：
   ```solidity
   // 测试合约
   contract ContractTest is Test {
       address constant TARGET = 0xBF6Cd8D57ffe3CBe3D78DEd8DA34345A3B736102;
       
       function setUp() public {
           // fork 指定链
           vm.createSelectFork("${RPC_URL}");
           // 准备测试账户和资金
           deal(address(this), 100 ether);
       }

       function testBuyTax() public {
           // 记录买入前余额
           uint256 balanceBefore = IERC20(TARGET).balanceOf(address(this));
           
           // 执行买入
           // ... 买入逻辑 ...
           
           // 验证手续费
           uint256 balanceAfter = IERC20(TARGET).balanceOf(address(this));
           // 计算实际收到的比例
           uint256 actualReceived = (balanceAfter - balanceBefore) * 10000 / expectedAmount;
           // 验证手续费是否符合预期（例如3%）
           assertApproxEqRel(actualReceived, 9700, 1); // 允许1%的误差
       }
   }
   ```

   方案B - Tenderly 模拟：
   1. 创建模拟交易
      - 选择目标合约和函数
      - 设置调用参数
      - 配置调用者地址和金额
   
   2. 执行模拟
      - 查看交易执行路径
      - 分析状态变化
      - 检查事件日志
   
   3. 分析结果
      - 验证手续费计算
      - 检查代币流向
      - 确认 gas 消耗

   方案C - 混合测试：
   1. 使用 Tenderly 快速验证
   2. 发现问题后用 Foundry 深入测试
   3. 编写自动化测试用例

## 注意事项
- fork 测试的优势：
  - 保持与主网状态一致
  - 包含所有依赖合约
  - 可以模拟任意账户
  - 可以修改状态进行测试

- 测试要点：
  - 选择合适的 fork 区块
  - 注意 RPC 节点的稳定性
  - 考虑测试的幂等性
  - 模拟不同的交易场景

- 安全考虑：
  - 使用私有 RPC 节点
  - 保护 API 密钥
  - 注意测试环境隔离

## 合约地址机制
1. 标准合约地址生成：
   - 计算公式：keccak256(RLP(deployer_address, nonce))[12:]
   - deployer_address：部署合约的地址
   - nonce：部署者的交易计数
   - 结果取后20字节作为地址

2. 跨链部署考虑：
   - 普通部署：不同链上通常会生成不同地址
     - 部署者 nonce 可能不同
     - 部署参数可能不同
     - 网络环境不同
   
   - CREATE2 部署：可以在不同链上获得相同地址
     - 需要相同的 salt 值
     - 相同的初始化代码
     - 相同的部署者地址
     - 常用于跨链应用

3. 地址冲突：
   - 理论上可能存在相同地址
   - 实际上因地址空间巨大（160位）极少发生
   - 建议使用地址检查工具验证

## 工具选择建议
1. 快速分析：
   - Honeypot.is 支持的链：TokenSniffer + Honeypot.is
   - 其他 EVM 链：TokenSniffer + 区块浏览器

2. 深入分析：
   - 已验证合约：源码分析 + 本地测试
   - 未验证合约：反编译 + fork 测试

3. 持续监控：
   - 设置交易监控
   - 定期重新验证费用变化

## 更新记录
- 2024-03-20：创建文档，添加初始工具评估
- 2024-03-20：更新解决方案流程，调整获取合约信息的必要性
- 2024-03-20：重构解决方案，增加通用性支持 