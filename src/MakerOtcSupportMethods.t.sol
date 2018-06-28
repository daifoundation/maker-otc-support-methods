pragma solidity ^0.4.23;

import "ds-test/test.sol";

import "./MakerOtcSupportMethods.sol";

contract MakerOtcSupportMethodsTest is DSTest {
    MakerOtcSupportMethods methods;

    function setUp() public {
        methods = new MakerOtcSupportMethods();
    }

    function testFail_basic_sanity() public {
        assertTrue(false);
    }

    function test_basic_sanity() public {
        assertTrue(true);
    }
}
