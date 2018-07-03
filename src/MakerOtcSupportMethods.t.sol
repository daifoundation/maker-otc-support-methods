pragma solidity ^0.4.23;

import "ds-test/test.sol";
import "maker-otc/matching_market.sol";
import "ds-token/token.sol";
import "./MakerOtcSupportMethods.sol";

contract FakeUser {
    MatchingMarket otc;

    function FakeUser(MatchingMarket otc_) public {
        otc = otc_;
    }

    function doApprove(address token) public {
        ERC20(token).approve(otc, uint(-1));
    }

    function doOffer(uint amount1, address token1, uint amount2, address token2) public {
        otc.offer(amount1, ERC20(token1), amount2, ERC20(token2), 0);
    }
}

contract MakerOtcSupportMethodsTest is DSTest {
    MakerOtcSupportMethods otcSupport;
    MatchingMarket otc;
    DSToken weth;
    DSToken mkr;
    FakeUser user;

    function setUp() public {
        weth = new DSToken("WETH");
        mkr = new DSToken("MKR");

        otcSupport = new MakerOtcSupportMethods();
        otc = new MatchingMarket(uint64(now + 1 weeks));
        otc.addTokenPairWhitelist(weth, mkr);
        weth.approve(otc);
        mkr.approve(otc);
        user = new FakeUser(otc);
        user.doApprove(weth);
        user.doApprove(mkr);
    }

    function createOffers(uint oQuantity, uint mkrAmount, uint wethAmount) public {
        for (uint i = 0; i < oQuantity; i ++) {
            user.doOffer(wethAmount / oQuantity, weth, mkrAmount / oQuantity, mkr);
        }
    }

    function testProxyGetOffers() public {
        weth.mint(20 ether);
        weth.transfer(user, 20 ether);
        createOffers(1, 3200 ether, 10 ether);
        createOffers(1, 2800 ether, 10 ether);
        // uint[] memory offers = 
        otcSupport.getOffers(OtcInterface(otc), weth, mkr);
    }

    function testProxyGetOffers2() public {
        weth.mint(20 ether);
        weth.transfer(user, 20 ether);
        createOffers(1, 3200 ether, 10 ether);
        createOffers(1, 2800 ether, 10 ether);
        otcSupport.getOffers2(OtcInterface(otc), weth, mkr);
    }

    function testProxyGetOffersAmountToSellAllPartialOrder() public {
        weth.mint(20 ether);
        weth.transfer(user, 20 ether);
        createOffers(1, 3200 ether, 10 ether);
        createOffers(1, 2800 ether, 10 ether);
        mkr.mint(4000 ether);
        mkr.approve(otcSupport, 4000 ether);
        uint offersToTake;
        bool takesPartialOrder;
        (offersToTake, takesPartialOrder) = otcSupport.getOffersAmountToSellAll(OtcInterface(otc), mkr, 4000 ether, weth);
        assertEq(offersToTake, 1);
        assertTrue(takesPartialOrder);
    }

    function testProxyGetOffersAmountToSellAllNoPartialOrder() public {
        weth.mint(20 ether);
        weth.transfer(user, 20 ether);
        createOffers(1, 3200 ether, 10 ether);
        createOffers(1, 800 ether, 4 ether);
        mkr.mint(4000 ether);
        mkr.approve(otcSupport, 4000 ether);
        uint offersToTake;
        bool takesPartialOrder;
        (offersToTake, takesPartialOrder) = otcSupport.getOffersAmountToSellAll(OtcInterface(otc), mkr, 4000 ether, weth);
        assertEq(offersToTake, 2);
        assertTrue(!takesPartialOrder);
    }

    function testProxyGetOffersAmountToBuyAllPartialOrder() public {
        weth.mint(20 ether);
        weth.transfer(user, 20 ether);
        createOffers(1, 3200 ether, 10 ether);
        createOffers(1, 2800 ether, 10 ether);
        mkr.mint(4400 ether);
        mkr.approve(otcSupport, 4400 ether);
        uint offersToTake;
        bool takesPartialOrder;
        (offersToTake, takesPartialOrder) = otcSupport.getOffersAmountToBuyAll(OtcInterface(otc), weth, 15 ether, mkr);
        assertEq(offersToTake, 1);
        assertTrue(takesPartialOrder);
    }

    function testProxyGetOffersAmountToBuyAllNoPartialOrder() public {
        weth.mint(15 ether);
        weth.transfer(user, 15 ether);
        createOffers(1, 3200 ether, 10 ether);
        createOffers(1, 2800 ether, 5 ether);
        mkr.mint(4400 ether);
        mkr.approve(otcSupport, 4400 ether);
        uint offersToTake;
        bool takesPartialOrder;
        (offersToTake, takesPartialOrder) = otcSupport.getOffersAmountToBuyAll(OtcInterface(otc), weth, 15 ether, mkr);
        assertEq(offersToTake, 2);
        assertTrue(!takesPartialOrder);
    }
}
