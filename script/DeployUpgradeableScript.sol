// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "../src/MemeTokenFactory.sol";
import "../src/MemeTokenInterface.sol";

contract DeployUpgradeableScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        vm.startBroadcast(deployerPrivateKey);
        
        // 部署工厂合约实现
        MemeTokenFactory factoryImpl = new MemeTokenFactory();
        
        // 部署工厂合约代理
        bytes memory factoryData = abi.encodeWithSelector(
            MemeTokenFactory.initialize.selector,
            deployer // 设置fee collector为部署者
        );
        
        ERC1967Proxy factoryProxy = new ERC1967Proxy(
            address(factoryImpl),
            factoryData
        );
        
        // 部署接口合约实现
        MemeTokenInterface interfaceImpl = new MemeTokenInterface();
        
        // 部署接口合约代理
        bytes memory interfaceData = abi.encodeWithSelector(
            MemeTokenInterface.initialize.selector,
            address(factoryProxy)
        );
        
        ERC1967Proxy interfaceProxy = new ERC1967Proxy(
            address(interfaceImpl),
            interfaceData
        );
        
        console.log("MemeTokenFactory implementation deployed at:", address(factoryImpl));
        console.log("MemeTokenFactory proxy deployed at:", address(factoryProxy));
        console.log("MemeTokenInterface implementation deployed at:", address(interfaceImpl));
        console.log("MemeTokenInterface proxy deployed at:", address(interfaceProxy));
        
        // 可选：创建一个初始代币作为示例
        MemeTokenFactory factory = MemeTokenFactory(address(factoryProxy));
        address exampleToken = factory.createMemeToken(
            "Example Meme", 
            "EXMEME", 
            1000000 * 10**18, // 初始供应量
            20, // 创建者费用 2%
            deployer // 创建者地址
        );
        console.log("Example token deployed at:", exampleToken);
        
        vm.stopBroadcast();
    }
}