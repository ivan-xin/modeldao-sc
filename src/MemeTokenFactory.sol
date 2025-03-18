// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "./MemeToken.sol";

contract MemeTokenFactory is Initializable, UUPSUpgradeable, OwnableUpgradeable {
    uint256 public platformFeePercent;
    address public feeCollector;
    address[] public allTokens;
    
    mapping(address => address[]) private creatorTokens;
    
    event TokenCreated(address indexed tokenAddress, string name, string symbol, address indexed creator);
    event PlatformFeeUpdated(uint256 newFeePercent);
    event FeeCollectorUpdated(address newFeeCollector);
    
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }
    
    function initialize(address _feeCollector) public initializer {
        __Ownable_init(msg.sender); // 或者传递其他地址作为初始所有者
        __UUPSUpgradeable_init();
        
        platformFeePercent = 10; // 1% (scaled by 1000)
        feeCollector = _feeCollector;
    }
    
    function createMemeToken(
        string memory _name,
        string memory _symbol,
        uint256 _initialSupply,
        uint256 _reserveRatio,
        uint256 _creatorFeePercent,
        address _creator
    ) external returns (address) {
        require(_creatorFeePercent <= 100, "Creator fee too high"); // max 10%
        
        MemeToken newToken = new MemeToken(
            _name,
            _symbol,
            _initialSupply,
            _reserveRatio,
            _creatorFeePercent,
            platformFeePercent,
            _creator,
            feeCollector
        );
        
        address tokenAddress = address(newToken);
        allTokens.push(tokenAddress);
        creatorTokens[_creator].push(tokenAddress);
        
        emit TokenCreated(tokenAddress, _name, _symbol, _creator);
        
        return tokenAddress;
    }
    
    function getCreatorTokens(address _creator) external view returns (address[] memory) {
        return creatorTokens[_creator];
    }
    
    function getAllTokens() external view returns (address[] memory) {
        return allTokens;
    }

    function getTokenCount() external view returns (uint256) {
        return allTokens.length;
    }
    
    function updatePlatformFee(uint256 _newFeePercent) external onlyOwner {
        require(_newFeePercent <= 30, "Fee too high"); // max 3%
        platformFeePercent = _newFeePercent;
        emit PlatformFeeUpdated(_newFeePercent);
    }
    
    function updateFeeCollector(address _newFeeCollector) external onlyOwner {
        require(_newFeeCollector != address(0), "Invalid address");
        feeCollector = _newFeeCollector;
        emit FeeCollectorUpdated(_newFeeCollector);
    }
    
    // 必须实现的UUPS升级授权函数
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}