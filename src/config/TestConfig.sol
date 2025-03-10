// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract TestConfig {
    struct DEXConfig {
        address router;
        address factory;
        address wrappedNative;
        string name;
        uint256 version;
    }

    mapping(uint256 => mapping(string => DEXConfig)) public dexConfigs;

    constructor() {
        // Ethereum Mainnet (chainId: 1)
        dexConfigs[1]["Uniswap_V2"] = DEXConfig({
            router: 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D,
            factory: 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f,
            wrappedNative: 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2,
            name: "Uniswap_V2",
            version: 2
        });

        dexConfigs[1]["Uniswap_V3"] = DEXConfig({
            router: 0xE592427A0AEce92De3Edee1F18E0157C05861564,
            factory: 0x1F98431c8aD98523631AE4a59f267346ea31F984,
            wrappedNative: 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2,
            name: "Uniswap_V3",
            version: 3
        });

        // BSC (chainId: 56)
        dexConfigs[56]["PancakeSwap_V2"] = DEXConfig({
            router: 0x10ED43C718714eb63d5aA57B78B54704E256024E,
            factory: 0xcA143Ce32Fe78f1f7019d7d551a6402fC5350c73,
            wrappedNative: 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c,
            name: "PancakeSwap_V2",
            version: 2
        });

        dexConfigs[56]["PancakeSwap_V3"] = DEXConfig({
            router: 0x13f4EA83D0bd40E75C8222255bc855a974568Dd4,
            factory: 0x0BFbCF9fa4f9C56B0F40a671Ad40E0805A091865,
            wrappedNative: 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c,
            name: "PancakeSwap_V3",
            version: 3
        });
    }

    function getDEXConfig(uint256 chainId, string memory dexName) public view returns (DEXConfig memory) {
        return dexConfigs[chainId][dexName];
    }
}
