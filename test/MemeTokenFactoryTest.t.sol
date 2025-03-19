// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/MemeTokenFactory.sol";
import "../src/MemeToken.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
contract MemeTokenFactoryTest is Test {
    MemeTokenFactory public factory;
    
    address public owner = address(1);
    address public user = address(2);
    address public platformAddress = address(3);
    
    function setUp() public {
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
        
        vm.stopPrank();
    }
    
    function testCreateToken() public {
        vm.startPrank(user);
        
        address tokenAddress = factory.createMemeToken(
            "New Meme", 
            "NMEME", 
            1000 * 10**18, // 初始供应量
            20, // 创建者费用 2%
            user // 创建者地址
        );
        
        vm.stopPrank();
        
        // 验证代币创建
        MemeToken token = MemeToken(payable(tokenAddress));
        assertEq(token.name(), "New Meme");
        assertEq(token.symbol(), "NMEME");
        assertEq(token.balanceOf(user), 1000 * 10**18);
        
        // 验证工厂状态
        assertEq(factory.getAllTokens().length, 1);
        assertEq(factory.allTokens(0), tokenAddress);
    }
    
    function testSetPlatformFee() public {
        vm.startPrank(owner);
        
        // 更改平台费用
        factory.updatePlatformFee(20); // 2%
        assertEq(factory.platformFeePercent(), 20);
        
        // 测试费用上限
        vm.expectRevert("Fee too high");
        factory.updatePlatformFee(60); // 6% - 超过限制
        
        vm.stopPrank();
        
        // 测试非所有者无法设置费用
        vm.startPrank(user);
        vm.expectRevert();
        factory.updatePlatformFee(15);
        vm.stopPrank();
    }
    
    function testWithdrawFees() public {
        // 先创建一个代币并购买一些代币来生成费用
        vm.startPrank(user);
        vm.deal(user, 10 ether); // 给用户一些ETH
        
        // 确保所有参数都有合理的值
        uint256 initialSupply = 1000 * 10**18;
        uint256 reserveRatio = 800000000000000000; // 80%
        uint256 creatorFeePercent = 20; // 2%
        
        // 打印参数值以便调试
        console.log("Initial Supply:", initialSupply);
        console.log("Reserve Ratio:", reserveRatio);
        console.log("Creator Fee Percent:", creatorFeePercent);
        
        address tokenAddress = factory.createMemeToken(
            "Fee Test", 
            "FEE", 
            initialSupply,
            creatorFeePercent,
            user
        );
        
        MemeToken token = MemeToken(payable(tokenAddress));
        
        // 打印代币信息
        console.log("Token created at:", tokenAddress);
        console.log("User ETH balance before:", address(user).balance);
        
        // 使用较小的金额购买代币，避免可能的溢出
        uint256 buyAmount = 1 ether;
        token.buyTokens{value: buyAmount}();
        
        console.log("User ETH balance after:", address(user).balance);
        console.log("Platform balance:", address(platformAddress).balance);
        
        vm.stopPrank();
        
        // 验证平台收到了费用
        uint256 platformBalance = address(platformAddress).balance;
        console.log("Final platform balance:", platformBalance);
        assertTrue(platformBalance > 0, "Platform should have received fees");
    }
    
    // 测试升级功能
    function testUpgrade() public {
        vm.startPrank(owner);
        
        // 部署新的实现合约
        MemeTokenFactory newImplementation = new MemeTokenFactory();
        
        // 获取代理地址
        address proxyAddress = address(factory);
        
        // 升级到新的实现
        ITransparentUpgradeableProxy proxy = ITransparentUpgradeableProxy(proxyAddress);
        proxy.upgradeToAndCall(address(newImplementation), "");
        
        // 验证升级成功 - 可以通过调用新实现中的函数来验证
        // 这里假设新实现有一些新功能或行为变化
        
        vm.stopPrank();
    }
}