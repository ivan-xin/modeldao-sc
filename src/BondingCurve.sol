// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "@openzeppelin/contracts/utils/math/Math.sol";

contract BondingCurve {
    using Math for uint256;
    
    // 常量定义 - 基于 pump.fun 项目
    uint256 public constant PRECISION = 1e18;
    uint256 public constant INITIAL_PRICE_DIVIDER = 800000;  // 初始价格除数
    uint256 public constant TOKEN_SELL_LIMIT_PERCENT = 8000;  // 80%
    uint256 public constant PROPORTION = 1280;  // 比例系数
    
    // 计算购买代币的数量
    function calculatePurchaseReturn(
        uint256 _supply,
        uint256 _depositAmount
    ) public pure returns (uint256) {
        // 计算当前价格
        uint256 currentPrice = calculateCurrentPrice(_supply);
        
        // 计算代币数量: depositAmount / currentPrice
        return (_depositAmount * PRECISION) / currentPrice;
    }
    
    // 计算出售代币获得的 ETH 数量
    function calculateSaleReturn(
        uint256 _supply,
        uint256 _sellAmount
    ) public pure returns (uint256) {
        require(_supply > 0 && _sellAmount <= _supply, "Invalid supply or sell amount");
        require(_sellAmount <= (_supply * TOKEN_SELL_LIMIT_PERCENT) / 10000, "Cannot sell more than limit");
        
        // 计算当前价格
        uint256 currentPrice = calculateCurrentPrice(_supply);
        
        // 计算 ETH 数量: sellAmount * currentPrice
        return (_sellAmount * currentPrice) / PRECISION;
    }
    
    // 计算当前代币价格 - 基于 pump.fun 的线性模型
    function calculateCurrentPrice(uint256 _supply) public pure returns (uint256) {
        if (_supply == 0) {
            // 初始价格
            return PRECISION / INITIAL_PRICE_DIVIDER;
        }
        
        // 基于当前供应量计算价格
        // price = initialPrice + (totalSupply / PROPORTION)
        uint256 initialPrice = PRECISION / INITIAL_PRICE_DIVIDER;
        uint256 supplyComponent = _supply / PROPORTION;
        
        return initialPrice + supplyComponent;
    }
}
