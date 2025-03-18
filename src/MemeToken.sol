// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./BondingCurve.sol";

contract MemeToken is ERC20, Ownable, BondingCurve {
    // 储备金
    uint256 public reserveBalance;
    
    // 费用设置
    uint256 public creatorFeePercent;
    uint256 public platformFeePercent;
    address public platformAddress;
    
    // 事件
    event TokensPurchased(address buyer, uint256 ethAmount, uint256 tokenAmount);
    event TokensSold(address seller, uint256 tokenAmount, uint256 ethAmount);
    
    constructor(
        string memory _name,
        string memory _symbol,
        uint256 _initialSupply,
        uint256 _reserveRatio,
        uint256 _creatorFeePercent,
        uint256 _platformFeePercent,
        address _creator,
        address _platformAddress
    ) ERC20(_name, _symbol) Ownable(_creator) BondingCurve(_reserveRatio) {
        require(_creatorFeePercent <= 100, "Creator fee too high"); // 最高10%
        
        creatorFeePercent = _creatorFeePercent;
        platformFeePercent = _platformFeePercent;
        platformAddress = _platformAddress;
        
        // 初始供应量铸造给创建者
        if (_initialSupply > 0) {
            _mint(_creator, _initialSupply);
        }

        // 初始化储备金，避免除以零错误
        reserveBalance = 1 ether; // 设置一个初始储备金
    }
    
    // 购买代币
    function buyTokens() external payable {
        require(msg.value > 0, "Must send ETH");
        
        // 计算平台费用
        uint256 platformFee = msg.value * platformFeePercent / 1000;
        
        // 计算创建者费用
        uint256 creatorFee = msg.value * creatorFeePercent / 1000;
        
        // 实际用于购买的ETH
        uint256 purchaseAmount = msg.value - platformFee - creatorFee;
        
        // 计算获得的代币数量
        uint256 tokenAmount = calculatePurchaseReturn(
            totalSupply(),
            reserveBalance,
            reserveRatio,
            purchaseAmount
        );
        
        // 更新储备金
        reserveBalance += purchaseAmount;
        
        // 铸造代币
        _mint(msg.sender, tokenAmount);
        
        // 发送费用
        if (platformFee > 0) {
            (bool platformSuccess, ) = platformAddress.call{value: platformFee}("");
            require(platformSuccess, "Platform fee transfer failed");
        }
        
        if (creatorFee > 0) {
            (bool creatorSuccess, ) = owner().call{value: creatorFee}("");
            require(creatorSuccess, "Creator fee transfer failed");
        }
        
        emit TokensPurchased(msg.sender, msg.value, tokenAmount);
    }
    
    // 出售代币
    function sellTokens(uint256 _amount) external {
        require(_amount > 0, "Amount must be greater than 0");
        require(balanceOf(msg.sender) >= _amount, "Insufficient balance");
        
        // 计算获得的ETH数量
        uint256 ethAmount = calculateSaleReturn(
            totalSupply(),
            reserveBalance,
            reserveRatio,
            _amount
        );
        
        // 计算平台费用
        uint256 platformFee = ethAmount * platformFeePercent / 1000;
        
        // 计算创建者费用
        uint256 creatorFee = ethAmount * creatorFeePercent / 1000;
        
        // 确保费用总和不超过 ethAmount，避免下溢
        uint256 totalFees = platformFee + creatorFee;
        if (totalFees > ethAmount) {
            platformFee = ethAmount / 2;
            creatorFee = ethAmount - platformFee;
            totalFees = ethAmount;
        }
    
        // 实际获得的ETH
        uint256 actualEthAmount = ethAmount - totalFees;
        
        // 确保合约有足够的ETH
        require(address(this).balance >= ethAmount, "Insufficient contract balance");
        require(reserveBalance >= ethAmount, "Insufficient reserve balance");
        
        // TODO: 这里需要考虑:
        // 1,贮备金额度是否应该加上平台手续费和创建者手续费？？？？ 
        // 2, 如果用户出售的代币数量大于储备金，那么应该如何处理？？？？
        // 更新储备金
        reserveBalance -= ethAmount + platformFee + creatorFee;
        
        // 销毁代币
        _burn(msg.sender, _amount);
        
        // 发送ETH
        (bool success, ) = msg.sender.call{value: actualEthAmount}("");
        require(success, "ETH transfer failed");
        
        // 发送费用
        if (platformFee > 0) {
            (bool platformSuccess, ) = platformAddress.call{value: platformFee}("");
            require(platformSuccess, "Platform fee transfer failed");
        }
        
        if (creatorFee > 0) {
            (bool creatorSuccess, ) = owner().call{value: creatorFee}("");
            require(creatorSuccess, "Creator fee transfer failed");
        }
        
        emit TokensSold(msg.sender, _amount, actualEthAmount);
    }
    
    // 获取当前购买价格估算
    function getBuyPrice(uint256 _ethAmount) external view returns (uint256) {
        uint256 platformFee = _ethAmount * platformFeePercent / 1000;
        uint256 creatorFee = _ethAmount * creatorFeePercent / 1000;
        uint256 purchaseAmount = _ethAmount - platformFee - creatorFee;
        
        return calculatePurchaseReturn(
            totalSupply(),
            reserveBalance,
            reserveRatio,
            purchaseAmount
        );
    }
    
    function getSellPrice(uint256 _tokenAmount) external view returns (uint256) {
        if (_tokenAmount == 0) return 0;
        
        uint256 ethAmount = calculateSaleReturn(
            totalSupply(),
            reserveBalance,
            reserveRatio,
            _tokenAmount
        );
        
        // 确保总费用不超过 ethAmount 的 90%
        uint256 maxTotalFee = ethAmount * 90 / 100;
        
        // 按比例分配费用
        uint256 totalFeePercent = platformFeePercent + creatorFeePercent;
        require(totalFeePercent > 0, "Fee percentage cannot be zero");

        uint256 platformFee = maxTotalFee * platformFeePercent / totalFeePercent;
        uint256 creatorFee = maxTotalFee - platformFee; // 确保总和等于 maxTotalFee
        
        require(ethAmount <= reserveBalance, "Sale would deplete reserves");

        return ethAmount - platformFee - creatorFee;
    }
    
    // 接收ETH
    receive() external payable {
        // 自动调用购买函数
        if (msg.value > 0) {
            this.buyTokens{value: msg.value}();
        }
    }
}