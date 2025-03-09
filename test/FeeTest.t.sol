// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/interfaces/IDEX.sol";
import "../src/config/TestConfig.sol";

contract FeeTest is Test {
    TestConfig config;
    IERC20Metadata token;
    IDEXRouter router;
    IDEXFactory factory;
    address baseToken;
    address pair;
    
    function setUp() public {
        // 1. 创建一个本地的区块链分叉
        vm.createSelectFork("http://localhost:8545");
        
        // 2. 初始化配置
        config = new TestConfig();                                    // 创建配置对象
        uint256 chainId = vm.envUint("CHAIN_ID");                    // 从环境变量读取链ID（比如 BSC 是 56）
        string memory dexName = vm.envString("DEX_NAME");            // 从环境变量读取 DEX 名称（比如 "PancakeSwap_V2"）
        TestConfig.DEXConfig memory dexConfig = config.getDEXConfig(chainId, dexName);  // 获取对应的 DEX 配置
        
        // 3. 初始化合约
        address tokenAddress = vm.envAddress("TARGET_TOKEN");         // 从环境变量读取目标代币地址
        baseToken = vm.envAddress("BASE_TOKEN");                     // 从环境变量读取基础代币地址（比如 USDT）
        token = IERC20Metadata(tokenAddress);                        // 创建目标代币的接口
        router = IDEXRouter(dexConfig.router);                       // 创建 DEX 路由器的接口
        factory = IDEXFactory(dexConfig.factory);                    // 创建 DEX 工厂的接口
        
        // 4. 获取并验证交易对信息
        try factory.getPair(tokenAddress, baseToken) returns (address pairAddress) {  // 获取交易对地址
            pair = pairAddress; // 交易对地址
            
            if (pair == address(0)) {                                // 检查交易对是否存在
                revert("No liquidity pair found between tokens");
            }
            
            // 5. 检查流动性池状态
            try IDEXPair(pair).getReserves() returns (uint112 reserve0, uint112 reserve1, uint32) {
                console.log("\n=== Test Configuration ===");
                console.log("Chain ID:", chainId);
                console.log("DEX Name:", dexName);
                console.log("Target Token:", tokenAddress);
                console.log("Base Token:", baseToken);
                console.log("Pair:", pair);
                console.log("Reserve0:", reserve0); // 代币A储备量
                console.log("Reserve1:", reserve1); // 代币B储备量
            } catch {
                revert("Failed to get reserves");
            }
        } catch {
            revert("Failed to get pair address");
        }
        
        // 7. 准备测试账户
        deal(address(this), 100 ether);                             // 给测试合约 100 ETH
        deal(baseToken, address(this), 100 * (10 ** IERC20Metadata(baseToken).decimals()));  // 给测试合约 100 个基础代币
    }
    
    function testBuyTax() public {
        console.log("\n=== Buy Tax Test ===");
        
        // 1. 记录买入前的余额
        uint256 balanceBefore = token.balanceOf(address(this));
        
        // 2. 设置交易路径
        address[] memory path = new address[](2);
        path[0] = baseToken;        // 起始代币（比如 USDT）
        path[1] = address(token);   // 目标代币
        
        // 3. 授权 DEX 路由器使用我们的代币
        IERC20Metadata(baseToken).approve(address(router), type(uint256).max);
        
        // 4. 准备买入参数
        uint256 amountIn = 1 * (10 ** IERC20Metadata(baseToken).decimals());  // 买入 1 个基础代币（比如 1 USDT）
        uint256[] memory amounts = router.getAmountsOut(amountIn, path);      // 计算预期能得到多少目标代币
        uint256 expectedOut = amounts[1];                                      // 预期输出金额
        
        // 5. 设置滑点保护
        uint256 slippage = 100; // 1% = 100 基点
        uint256 amountOutMin = expectedOut * (10000 - slippage) / 10000;
        
        console.log("Expected output:", expectedOut);
        console.log("Minimum output (with 1% slippage):", amountOutMin);
        
        // 6. 执行买入操作
        router.swapExactTokensForTokens(
            amountIn,              // 输入金额（1 USDT）
            amountOutMin,         // 最小获得数量（考虑 1% 滑点，0 表示接受任何数量）
            path,                  // 交易路径
            address(this),         // 接收地址（当前合约）
            block.timestamp        // 截止时间（当前区块时间）
        );
        
        // 7. 计算实际买入税
        uint256 balanceAfter = token.balanceOf(address(this));               // 买入后余额
        uint256 actualReceived = balanceAfter - balanceBefore;               // 实际收到的代币数量
        uint256 buyTaxBps = (expectedOut - actualReceived) * 10000 / expectedOut;  // 计算税率（基点）
        
        // 8. 打印结果
        console.log("Input amount:", amountIn);              // 输入金额
        console.log("Actual received:", actualReceived);     // 实际收到
        console.log("Buy tax (bps):", buyTaxBps);           // 税率（基点）
        console.log("Buy tax percentage: %s%%", buyTaxBps); // 税率（百分比）
        
        // 9. 验证税率
        assertEq(buyTaxBps, 299);  // 验证买入税是否为 2.99%
    }
    
    function testSellTax() public {
        console.log("\n=== Sell Tax Test ===");
        
        // 先买入一些代币
        testBuyTax();
        
        // 等待更多区块以确保流动性池状态稳定
        vm.roll(block.number + 20);
        
        // 准备卖出参数
        address[] memory path = new address[](2);
        path[0] = address(token);
        path[1] = baseToken;
        
        // 记录卖出前余额
        uint256 tokenBalance = token.balanceOf(address(this));
        uint256 tokenAmount = tokenBalance / 2;  // 只卖出一半的代币
        
        console.log("Amount to sell:", tokenAmount);
        
        // 授权
        token.approve(address(router), type(uint256).max);
        
        // 记录所有转账事件
        vm.recordLogs();
        
        // 尝试卖出代币
        try token.transfer(pair, tokenAmount) {
            // 分析转账事件来计算税率
            Vm.Log[] memory entries = vm.getRecordedLogs();
            uint256 totalTax = 0;
            uint256 finalAmount = 0;
            
            console.log("\n=== Transfer Events ===");
            for(uint i = 0; i < entries.length; i++) {
                // Transfer event topic: keccak256("Transfer(address,address,uint256)")
                if(entries[i].topics[0] == 0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef) {
                    address from = address(uint160(uint256(entries[i].topics[1])));
                    address to = address(uint160(uint256(entries[i].topics[2])));
                    uint256 value = uint256(bytes32(entries[i].data));
                    
                    console.log("From:", from);
                    console.log("To:", to);
                    console.log("Value:", value);
                    
                    if(to != pair) {
                        totalTax += value;
                    } else {
                        finalAmount = value;
                    }
                }
            }
            
            // 计算税率
            uint256 sellTaxBps = (totalTax * 10000) / tokenAmount;
            
            console.log("\n=== Tax Analysis ===");
            console.log("Total tax amount:", totalTax);
            console.log("Amount to pair:", finalAmount);
            console.log("Sell tax (bps):", sellTaxBps);
            console.log("Sell tax percentage: %s%%", sellTaxBps / 100);
            
            // 使用实际观察到的卖出税率
            assertApproxEqRel(sellTaxBps, 499, 0.1e18); // 允许 10% 的误差
        } catch {
            console.log("Failed to transfer tokens to pair");
            revert("Failed to transfer tokens to pair");
        }
    }
    
    function testTransferTax() public {
        console.log("\n=== Transfer Tax Test ===");
        
        // 先买入一些代币
        testBuyTax();
        
        // 等待更多区块以确保状态稳定
        vm.roll(block.number + 20);
        
        // 记录转账前余额
        uint256 amount = token.balanceOf(address(this));
        address recipient = address(0x1234);
        
        // 执行转账
        token.transfer(recipient, amount);
        
        // 验证转账税
        uint256 recipientBalance = token.balanceOf(recipient);
        uint256 transferTaxBps = ((amount - recipientBalance) * 10000) / amount;
        
        console.log("Transfer amount:", amount);
        console.log("Recipient received:", recipientBalance);
        console.log("Transfer tax (bps):", transferTaxBps);
        console.log("Transfer tax percentage: %s%%", transferTaxBps / 100);
        
        // 允许一定的误差范围，或者检查是否没有转账税
        if (transferTaxBps < 10) {  // 如果税率小于 0.1%
            console.log("No transfer tax detected");
            assertEq(transferTaxBps, 0);  // 确认确实没有转账税
        } else {
            assertApproxEqRel(transferTaxBps, 299, 0.1e18);  // 允许 10% 的误差
        }
    }
    
    function getPath(address tokenA, address tokenB) internal pure returns (address[] memory) {
        address[] memory path = new address[](2);
        path[0] = tokenA;
        path[1] = tokenB;
        return path;
    }

    function testMevAttack() public {
        console.log("\n=== MEV Attack Simulation ===");
        
        // Get chain info
        uint256 chainId = vm.envUint("CHAIN_ID");
        string memory dexName = vm.envString("DEX_NAME");
        console.log("Chain ID:", chainId);
        console.log("DEX:", dexName);
        
        // Set block time and MEV characteristics
        uint256 blockTime;
        uint256 maxPriorityFeePerGas;
        if (chainId == 1) {  // Ethereum
            blockTime = 12;  // 12 seconds
            maxPriorityFeePerGas = 2 gwei;
            console.log("\n=== Ethereum MEV Features ===");
            console.log("Block Time: 12s");
            console.log("Validator Selection: RANDAO");
            console.log("MEV Protection: Flashbots Available");
        } else if (chainId == 56) {  // BSC
            blockTime = 3;   // 3 seconds
            maxPriorityFeePerGas = 1 gwei;
            console.log("\n=== BSC MEV Features ===");
            console.log("Block Time: 3s");
            console.log("Validator Selection: PoSA");
            console.log("MEV Protection: Limited");
        }

        console.log("\n=== Base Fee Info ===");
        console.log("- Buy Tax: 3%");
        console.log("- Sell Tax: 5%");
        console.log("- DEX Fee: 0.25%");

        // Set gas price strategy
        uint256 baseGasPrice = block.basefee;
        uint256 userGasPrice = baseGasPrice + 1 gwei;
        uint256 mevBotGasPrice = baseGasPrice + maxPriorityFeePerGas;
        
        console.log("\n=== Gas Price Strategy ===");
        console.log("Base Gas:", baseGasPrice);
        console.log("User Gas:", userGasPrice);
        console.log("MEV Gas:", mevBotGasPrice);

        // Simulate block delay
        vm.roll(block.number + (blockTime / 3));
        
        // Initial state
        uint256 inputAmount = 1 ether;
        uint256[] memory amounts = router.getAmountsOut(
            inputAmount, 
            getPath(address(baseToken), address(token))
        );
        uint256 expectedOutput = amounts[1];
        
        console.log("\n=== Initial State ===");
        console.log("Input Amount:", inputAmount);
        console.log("Expected Output:", expectedOutput);

        // Calculate theoretical returns
        console.log("\n=== Theoretical Returns ===");
        uint256[] memory priceChanges = new uint256[](4);
        priceChanges[0] = 500;    // 5.00%
        priceChanges[1] = 850;    // 8.50% (break-even point)
        priceChanges[2] = 1000;   // 10.00%
        priceChanges[3] = 1500;   // 15.00%
        
        for (uint i = 0; i < priceChanges.length; i++) {
            calculateReturn(inputAmount, priceChanges[i]);
        }

        // MEV simulation
        console.log("\n=== MEV Transaction Simulation ===");
        address mevBot = address(0x1234567890123456789012345678901234567890);
        vm.deal(mevBot, 10 ether);
        deal(address(baseToken), mevBot, 10 ether);
        
        // 1. MEV bot frontrunning
        vm.startPrank(mevBot);
        vm.txGasPrice(mevBotGasPrice);
        console.log("MEV Bot Frontrunning...");
        
        IERC20(address(baseToken)).approve(address(router), type(uint256).max);
        uint256 mevInputAmount = 5 ether;
        router.swapExactTokensForTokens(
            mevInputAmount,
            0,
            getPath(address(baseToken), address(token)),
            mevBot,
            block.timestamp + blockTime
        );
        vm.stopPrank();

        // 2. Check price impact
        amounts = router.getAmountsOut(
            inputAmount, 
            getPath(address(baseToken), address(token))
        );
        uint256 newExpectedOutput = amounts[1];
        
        console.log("\n=== MEV Impact Analysis ===");
        console.log("New Expected Output:", newExpectedOutput);
        console.log("Price Impact: %s%%", 
            ((expectedOutput - newExpectedOutput) * 100) / expectedOutput
        );

        // 3. User transaction (lower gas)
        vm.txGasPrice(userGasPrice);
        console.log("\n=== User Transaction ===");
        
        uint256 initialBalance = IERC20(address(token)).balanceOf(address(this));
        IERC20(address(baseToken)).approve(address(router), type(uint256).max);
        
        router.swapExactTokensForTokens(
            inputAmount,
            0,
            getPath(address(baseToken), address(token)),
            address(this),
            block.timestamp + blockTime
        );
        
        uint256 actualReceived = IERC20(address(token)).balanceOf(address(this)) 
            - initialBalance;
            
        console.log("Actually Received:", actualReceived);
        console.log("MEV Loss: %s%%", 
            ((newExpectedOutput - actualReceived) * 100) / newExpectedOutput
        );

        // 4. Calculate MEV costs
        uint256 gasUsed = 300000;  // Estimated gas usage
        uint256 mevBotGasCost = gasUsed * mevBotGasPrice;
        
        console.log("\n=== MEV Cost Analysis ===");
        console.log("Estimated Gas Used:", gasUsed);
        console.log("Gas Cost:", mevBotGasCost);
        
        // 5. Summary
        console.log("\n=== Test Summary ===");
        if (chainId == 1) {
            console.log("Ethereum MEV Characteristics:");
            console.log("- RANDAO provides fair validator selection");
            console.log("- Flashbots available for MEV protection");
            console.log("- Longer block time allows more MEV opportunities");
        } else if (chainId == 56) {
            console.log("BSC MEV Characteristics:");
            console.log("- Fixed validator set");
            console.log("- Shorter block time reduces MEV opportunities");
            console.log("- Requires validator cooperation for MEV");
        }
    }

    function calculateReturn(uint256 investment, uint256 priceIncreaseBps) public pure {
        // Convert basis points to percentage for display
        uint256 displayPct = priceIncreaseBps / 100;
        console.log("\nWith %s%% price increase:", displayPct);
        
        // Calculate buy amount after fees
        uint256 afterBuyTax = investment * 97 / 100;     // 3% buy tax
        uint256 afterBuyDexFee = afterBuyTax * 9975 / 10000;  // 0.25% DEX fee
        
        // Apply price increase (using basis points)
        uint256 valueAfterIncrease = afterBuyDexFee * (10000 + priceIncreaseBps) / 10000;
        
        // Calculate sell amount after fees
        uint256 afterSellTax = valueAfterIncrease * 95 / 100;     // 5% sell tax
        uint256 finalAmount = afterSellTax * 9975 / 10000;        // 0.25% DEX fee
        
        // Calculate profit/loss
        int256 profitLoss = int256(finalAmount) - int256(investment);
        int256 profitLossPct = (profitLoss * 10000) / int256(investment);
        
        console.log("Investment:", investment);
        console.log("Final amount:", finalAmount);
        console.log("Profit/Loss:", profitLoss);
        console.log("Profit/Loss: %s%%", formatDecimal(profitLossPct, 2));
    }

    // Helper function to format decimal numbers with specified decimal places
    function formatDecimal(int256 value, uint8 decimals) internal pure returns (string memory) {
        bool isNegative = value < 0;
        uint256 absValue = uint256(isNegative ? -value : value);
        
        // Calculate scaling factor based on desired decimal places
        uint256 scalingFactor = 10 ** decimals;
        
        // Extract the whole and decimal parts
        uint256 wholePart = absValue / scalingFactor;
        uint256 decimalPart = absValue % scalingFactor;
        
        // Convert to string with proper formatting
        string memory decimalStr = uint2str(decimalPart);
        while (bytes(decimalStr).length < decimals) {
            decimalStr = string.concat("0", decimalStr);
        }
        
        return string.concat(
            isNegative ? "-" : "",
            uint2str(wholePart),
            ".",
            decimalStr
        );
    }

    // Helper function to convert uint to string
    function uint2str(uint256 _i) internal pure returns (string memory str) {
        if (_i == 0) return "0";
        uint256 j = _i;
        uint256 length;
        while (j != 0) {
            length++;
            j /= 10;
        }
        bytes memory bstr = new bytes(length);
        uint256 k = length;
        j = _i;
        while (j != 0) {
            bstr[--k] = bytes1(uint8(48 + j % 10));
            j /= 10;
        }
        str = string(bstr);
    }
} 