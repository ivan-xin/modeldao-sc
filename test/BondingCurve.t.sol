
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/BondingCurve.sol";

contract BondingCurveTest is Test {
    BondingCurve public bondingCurve;
    uint256 constant PRECISION = 1e18;
    
    function setUp() public {
        bondingCurve = new BondingCurve(PRECISION / 2); // 50% reserve ratio
    }
}
