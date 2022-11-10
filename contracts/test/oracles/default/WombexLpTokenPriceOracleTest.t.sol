// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "../../config/BaseTest.t.sol";
import { WombexLpTokenPriceOracle } from "../../../oracles/default/WombexLpTokenPriceOracle.sol";
import { MasterPriceOracle } from "../../../oracles/MasterPriceOracle.sol";

contract WombexLpTokenPriceOracleTest is BaseTest {
  WombexLpTokenPriceOracle private oracle;

  function setUp() public forkAtBlock(BSC_MAINNET, 22933276) {
    oracle = new WombexLpTokenPriceOracle(MasterPriceOracle(ap.getAddress("MasterPriceOracle")));
  }

  function testPrice() public {
    // price for Wombex WBNB asset
    uint256 price = oracle.price(0x74f019A5C4eD2C2950Ce16FaD7Af838549092c5b);
    emit log_uint(price);
    assertEq(price, 939502768449285698);
  }
}
