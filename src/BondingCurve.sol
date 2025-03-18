// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/utils/math/SafeCast.sol";

contract BondingCurve {
    using Math for uint256;
    using SafeCast for uint256;
    
    // 曲线参数
    uint256 public constant PRECISION = 1e18;
    uint256 public reserveRatio; // 储备比率，表示为PRECISION的百分比
    
    constructor(uint256 _reserveRatio) {
        require(_reserveRatio > 0 && _reserveRatio <= PRECISION, "Invalid reserve ratio");
        reserveRatio = _reserveRatio;
    }
    
    // 计算购买代币的价格
    function calculatePurchaseReturn(
        uint256 _supply,
        uint256 _reserveBalance,
        uint256 _reserveRatio,
        uint256 _depositAmount
    ) public pure returns (uint256) {
        if (_supply == 0) {
            return _depositAmount;
        }
        
        // 使用公式: tokenAmount = supply * ((1 + depositAmount / reserveBalance) ^ (reserveRatio / PRECISION) - 1)
        uint256 result;
        uint256 baseN = _reserveBalance + _depositAmount;
        uint256 baseD = _reserveBalance;
        
        // 特殊情况处理
        if (_reserveRatio == PRECISION) {
            result = _supply * _depositAmount / _reserveBalance;
        } else {
            // 使用近似计算
            uint256 temp1 = baseN * PRECISION / baseD;
            uint256 temp2 = power(temp1, _reserveRatio, PRECISION);
            result = _supply * (temp2 - PRECISION) / PRECISION;
        }
        
        return result;
    }
    
    // 计算出售代币的价格
    function calculateSaleReturn(
        uint256 _supply,
        uint256 _reserveBalance,
        uint256 _reserveRatio,
        uint256 _sellAmount
    ) public pure returns (uint256) {
        require(_supply > 0 && _sellAmount <= _supply, "Invalid supply or sell amount");
        
        // 使用公式: etherAmount = reserveBalance * (1 - (1 - sellAmount / supply) ^ (PRECISION / reserveRatio))
        uint256 result;
        
        // 特殊情况处理
        if (_reserveRatio == PRECISION) {
            result = _reserveBalance * _sellAmount / _supply;
        } else {
            uint256 temp1 = PRECISION - (_sellAmount * PRECISION / _supply);
            uint256 temp2 = power(temp1, PRECISION, _reserveRatio);
            result = _reserveBalance * (PRECISION - temp2) / PRECISION;
        }
        
        return result;
    }
    
    // 使用OpenZeppelin数学库的安全计算
    function power(uint256 _baseN, uint256 _baseD, uint256 _expN) internal pure returns (uint256) {
        require(_baseD != 0, "Division by zero");
        
        // 计算基数比例 (baseN / baseD)
        uint256 base = Math.mulDiv(_baseN, PRECISION, _baseD);
        // 计算指数因子 (expN / PRECISION)
        uint256 exponent = _expN;

        // 处理特殊情况
        if (base == PRECISION) return PRECISION; // x^0 = 1
        if (exponent == 0) return PRECISION; // 1^n = 1
        if (exponent == PRECISION) return base; // x^1 = x

        // 使用泰勒展开计算自然对数
        uint256 lnx = 0;
        uint256 term = (base - PRECISION) * PRECISION / (base + PRECISION);
        uint256 numerator = term;
        uint256 denominator = 1;
        
        for (uint256 i = 1; i <= 8; i += 2) {
            lnx += numerator / denominator;
            numerator = Math.mulDiv(numerator, term, PRECISION) * term / PRECISION;
            denominator += 2;
        }
        lnx *= 2;

        // 计算指数：e^(exponent * lnx / PRECISION)
        uint256 exponentTimesLnX = Math.mulDiv(exponent, lnx, PRECISION);
        uint256 result = PRECISION;
        uint256 termX = PRECISION;
        
        for (uint256 j = 1; j <= 8; j++) {
            termX = Math.mulDiv(termX, exponentTimesLnX, j * PRECISION);
            result += termX;
        }

        return Math.mulDiv(result, base, PRECISION);
    }
}