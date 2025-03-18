// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "../src/MemeTokenFactory.sol";
import "../src/MemeTokenInterface.sol";

contract UpgradeContractsScript is Script {
    // ERC1967 implementation slot
    bytes32 constant IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address factoryProxy = vm.envAddress("FACTORY_PROXY_ADDRESS");
        address interfaceProxy = vm.envAddress("INTERFACE_PROXY_ADDRESS");
        
        // 验证部署者是否是合约所有者
        address deployer = vm.addr(deployerPrivateKey);
        console.log("Deployer address:", deployer);
        
        // 检查当前实现
        address currentFactoryImpl = _getImplementation(factoryProxy);
        address currentInterfaceImpl = _getImplementation(interfaceProxy);
        
        console.log("Current Factory implementation:", currentFactoryImpl);
        console.log("Current Interface implementation:", currentInterfaceImpl);
        
        vm.startBroadcast(deployerPrivateKey);
        
        // 1. 升级工厂合约
        console.log("\n--- Upgrading Factory Contract ---");
        MemeTokenFactory newFactoryImpl = new MemeTokenFactory();
        console.log("New Factory implementation deployed at:", address(newFactoryImpl));
        
        try IUUPSUpgradeable(factoryProxy).upgradeTo(address(newFactoryImpl)) {
            console.log("Factory upgrade transaction sent successfully");
        } catch Error(string memory reason) {
            console.log("Factory upgrade failed:", reason);
        } catch {
            console.log("Factory upgrade failed with unknown error");
        }
        
        // 2. 升级接口合约
        console.log("\n--- Upgrading Interface Contract ---");
        MemeTokenInterface newInterfaceImpl = new MemeTokenInterface();
        console.log("New Interface implementation deployed at:", address(newInterfaceImpl));
        
        try IUUPSUpgradeable(interfaceProxy).upgradeTo(address(newInterfaceImpl)) {
            console.log("Interface upgrade transaction sent successfully");
        } catch Error(string memory reason) {
            console.log("Interface upgrade failed:", reason);
        } catch {
            console.log("Interface upgrade failed with unknown error");
        }
        
        vm.stopBroadcast();
        
        // 验证升级结果
        console.log("\n--- Verifying Upgrades ---");
        
        // 检查新的实现地址
        address newFactoryImplAddr = _getImplementation(factoryProxy);
        address newInterfaceImplAddr = _getImplementation(interfaceProxy);
        
        console.log("New Factory implementation:", newFactoryImplAddr);
        console.log("New Interface implementation:", newInterfaceImplAddr);
        
        // 验证工厂合约升级
        if (newFactoryImplAddr == address(newFactoryImpl)) {
            console.log("[OK] Factory upgrade successful!");
        } else {
            console.log("[ERROR] Factory upgrade failed or not confirmed!");
            if (newFactoryImplAddr == currentFactoryImpl) {
                console.log("   Implementation address unchanged");
            } else {
                console.log("   Implementation changed to unexpected address");
            }
        }
        
        // 验证接口合约升级
        if (newInterfaceImplAddr == address(newInterfaceImpl)) {
            console.log("[OK] Interface upgrade successful!");
        } else {
            console.log("[ERROR] Interface upgrade failed or not confirmed!");
            if (newInterfaceImplAddr == currentInterfaceImpl) {
                console.log("   Implementation address unchanged");
            } else {
                console.log("   Implementation changed to unexpected address");
            }
        }
        
        // 总结
        if (newFactoryImplAddr == address(newFactoryImpl) && 
            newInterfaceImplAddr == address(newInterfaceImpl)) {
            console.log("\n[OK] All upgrades completed successfully!");
        } else {
            console.log("\n[WARN] Some upgrades failed or could not be confirmed!");
        }
        
        // 保存新的实现地址到文件
        string memory deploymentInfo = string(abi.encodePacked(
            "FACTORY_PROXY_ADDRESS=", vm.toString(factoryProxy), "\n",
            "INTERFACE_PROXY_ADDRESS=", vm.toString(interfaceProxy), "\n",
            "FACTORY_IMPLEMENTATION=", vm.toString(newFactoryImplAddr), "\n",
            "INTERFACE_IMPLEMENTATION=", vm.toString(newInterfaceImplAddr), "\n",
            "UPGRADE_TIMESTAMP=", vm.toString(block.timestamp)
        ));
        
        vm.writeFile("./upgrade-info.env", deploymentInfo);
        console.log("Upgrade information saved to upgrade-info.env");
    }
    
    // 使用 vm.load 获取实现地址
    function _getImplementation(address proxy) internal view returns (address) {
        bytes32 implBytes = vm.load(proxy, IMPLEMENTATION_SLOT);
        return address(uint160(uint256(implBytes)));
    }
}

interface IUUPSUpgradeable {
    function upgradeTo(address newImplementation) external;
}