// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/MemeToken.sol";
import "../src/MemeTokenFactory.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

contract MemeTokenTest is Test {
    MemeTokenFactory public factory;
    MemeToken public token;
    
    address public owner = address(1);
    address public user1 = address(2);
    address public user2 = address(3);
    address public platformAddress = address(4);
    
    function setUp() public {
        // 设置工厂合约 - 使用可升级模式
        vm.startPrank(owner);
        
        // 部署实现合约
        MemeTokenFactory implementation = new MemeTokenFactory();
        
        // 部署代理合约
        bytes memory initData = abi.encodeWithSelector(
            MemeTokenFactory.initialize.selector, 
            platformAddress
        );
        
        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(
            address(implementation),
            owner,  // 管理员地址
            initData
        );
        
        // 通过代理访问合约
        factory = MemeTokenFactory(address(proxy));
        
        // 创建一个测试代币
        address tokenAddress = factory.createMemeToken(
            "Test Meme", 
            "MEME", 
            1000 * 10**18, // 初始供应量
            800000000000000000, // 储备比率 (80%)
            20, // 创建者费用 2%
            owner // 创建者地址
        );
        
        token = MemeToken(payable(tokenAddress));
        vm.stopPrank();
        
        // 给测试用户一些ETH
        vm.deal(user1, 100 ether);
        vm.deal(user2, 100 ether);
    }
    
    function testCreateToken() public {
        vm.startPrank(owner);
        
        address tokenAddress = factory.createMemeToken(
            "Test Meme 2", // 修改名称以区分
            "MEME2", // 修改符号以区分
            1000 * 10**18,
            800000000000000000,
            20,
            owner
        );
        
        MemeToken newToken = MemeToken(payable(tokenAddress));
        
        assertEq(newToken.name(), "Test Meme 2");
        assertEq(newToken.symbol(), "MEME2");
        
        assertEq(factory.getAllTokens().length, 2); // 修改为2，因为setUp已经创建了一个token
        
        vm.stopPrank();
    }
    
    function testBuyTokens() public {
        vm.startPrank(user1);
        
        uint256 initialBalance = token.balanceOf(user1);
        uint256 initialEthBalance = address(user1).balance;
        
        uint256 buyAmount = 1 ether;
        token.buyTokens{value: buyAmount}();
        
        assertTrue(token.balanceOf(user1) > initialBalance);
        assertTrue(address(user1).balance == initialEthBalance - buyAmount);
        
        vm.stopPrank();
    }
    
    function testSellTokens() public {
        vm.startPrank(user1);
        
        // 使用较小的金额
        uint256 buyAmount = 0.1 ether;
        token.buyTokens{value: buyAmount}();
        uint256 tokenBalance = token.balanceOf(user1);
        
        uint256 ethBalanceBefore = address(user1).balance;
        console.log("ethBalanceBefore:", ethBalanceBefore);
        
        // 只卖出一小部分代币
        uint256 sellAmount = tokenBalance / 10;

        // 打印调试信息
        console.log("Token Balance:", tokenBalance);
        console.log("Sell Amount:", sellAmount);
        console.log("token.balanceOf(user1)",token.balanceOf(user1));
        console.log("sellAmount:",tokenBalance - sellAmount);
        
        token.sellTokens(sellAmount);
        
        console.log("Sell OK");
        assertEq(token.balanceOf(user1), tokenBalance - sellAmount);
        assertTrue(address(user1).balance > ethBalanceBefore);
        
        vm.stopPrank();
    }
    
    function testPriceCalculation() public {
        vm.startPrank(user1);
        
        // 使用较小的金额
        uint256 buyAmount = 0.1 ether;
        
        uint256 buyPrice = token.getBuyPrice(buyAmount);
        assertTrue(buyPrice > 0);
        
        token.buyTokens{value: buyAmount}();
        uint256 tokenBalance = token.balanceOf(user1);
        
        // 只卖出一小部分代币
        uint256 sellAmount = tokenBalance / 10;
        uint256 sellPrice = token.getSellPrice(sellAmount);
        
        assertTrue(sellPrice > 0);
        assertTrue(sellPrice < buyAmount); // 卖出价格应该小于买入价格
        
        vm.stopPrank();
    }
    
    function testFees() public {
        uint256 ownerBalanceBefore = address(owner).balance;
        uint256 platformBalanceBefore = address(platformAddress).balance;
        
        vm.startPrank(user1);
        token.buyTokens{value: 10 ether}();
        vm.stopPrank();
        
        assertTrue(address(owner).balance > ownerBalanceBefore);
        assertTrue(address(platformAddress).balance > platformBalanceBefore);
        
        // 添加具体费用验证
        uint256 ownerFee = address(owner).balance - ownerBalanceBefore;
        uint256 platformFee = address(platformAddress).balance - platformBalanceBefore;
        assertTrue(ownerFee > 0);
        assertTrue(platformFee > 0);
    }
}