// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "./MemeTokenFactory.sol";
import "./MemeToken.sol";

contract MemeTokenInterface is Initializable, UUPSUpgradeable, OwnableUpgradeable {
    MemeTokenFactory public factory;
    
    struct TokenInfo {
        string name;
        string symbol;
        uint256 totalSupply;
        uint256 reserveBalance;
        uint256 currentPrice;
        uint256 creatorFeePercent;
        address creator;
    }
    
    struct TokenBalance {
        address tokenAddress;
        string name;
        string symbol;
        uint256 balance;
        uint256 currentPrice;
    }
    
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }
    
    function initialize(address _factoryAddress) public initializer {
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();
        
        factory = MemeTokenFactory(_factoryAddress);
    }
    
    function updateFactoryAddress(address _newFactoryAddress) external onlyOwner {
        factory = MemeTokenFactory(_newFactoryAddress);
    }
    
    function getTokenInfo(address _tokenAddress) external view returns (TokenInfo memory) {
        MemeToken token = MemeToken(payable(_tokenAddress));
        
        return TokenInfo({
            name: token.name(),
            symbol: token.symbol(),
            totalSupply: token.totalSupply(),
            reserveBalance: token.reserveBalance(),
            // 修改：使用正确的方法名，根据 MemeToken 合约中的实际方法
            currentPrice: calculatePurchasePrice(token, 10**18), // 价格为1个代币的价格
            creatorFeePercent: token.creatorFeePercent(),
            creator: token.owner()
        });
    }

    // 添加辅助函数计算价格
    function calculatePurchasePrice(MemeToken token, uint256 amount) internal view returns (uint256) {
        // 使用 token 的 getBuyPrice 方法，如果存在的话
        return token.getBuyPrice(amount);
    }

    function getAllTokens() external view returns (TokenInfo[] memory) {
        address[] memory tokenAddresses = factory.getAllTokens();
        TokenInfo[] memory tokens = new TokenInfo[](tokenAddresses.length);
        
        for (uint i = 0; i < tokenAddresses.length; i++) {
            // 修改：直接调用 getTokenInfo 而不是 this.getTokenInfo
            tokens[i] = this.getTokenInfo(tokenAddresses[i]);
        }
        
        return tokens;
    }
    
    function getUserBalances(address _user) external view returns (TokenBalance[] memory) {
        address[] memory tokenAddresses = factory.getAllTokens();
        
        // 首先计算用户拥有余额的代币数量
        uint256 tokenCount = 0;
        for (uint i = 0; i < tokenAddresses.length; i++) {
            MemeToken token = MemeToken(payable(tokenAddresses[i])); // 修改：添加 payable
            if (token.balanceOf(_user) > 0) {
                tokenCount++;
            }
        }
        
        // 创建结果数组
        TokenBalance[] memory balances = new TokenBalance[](tokenCount);
        
        // 填充结果数组
        uint256 resultIndex = 0;
        for (uint i = 0; i < tokenAddresses.length; i++) {
            MemeToken token = MemeToken(payable(tokenAddresses[i])); // 修改：添加 payable
            uint256 balance = token.balanceOf(_user);
            
            if (balance > 0) {
                balances[resultIndex] = TokenBalance({
                    tokenAddress: tokenAddresses[i],
                    name: token.name(),
                    symbol: token.symbol(),
                    balance: balance,
                    // 修改：使用辅助函数计算价格
                    currentPrice: calculatePurchasePrice(token, 10**18)
                });
                resultIndex++;
            }
        }
        
        return balances;
    }
    
    // 必须实现的UUPS升级授权函数
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}
