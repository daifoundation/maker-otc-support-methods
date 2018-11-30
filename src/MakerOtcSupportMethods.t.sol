pragma solidity ^0.4.24;

import "ds-test/test.sol";
import "maker-otc/matching_market.sol";
import "ds-token/token.sol";
import "./MakerOtcSupportMethods.sol";

contract FakeUser {
    MatchingMarket otc;

    constructor(MatchingMarket otc_) public {
        otc = otc_;
    }

    function doApprove(address token) public {
        ERC20(token).approve(otc, uint(-1));
    }

    function doLimitOffer(uint amount1, address token1, uint amount2, address token2, bool forceSellAmt) public {
        otc.limitOffer(amount1, ERC20(token1), amount2, ERC20(token2), forceSellAmt, 0);
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
        weth.approve(otc);
        mkr.approve(otc);
        user = new FakeUser(otc);
        user.doApprove(weth);
        user.doApprove(mkr);
    }

    function createOffers(uint oQuantity, uint mkrAmount, uint wethAmount) public {
        for (uint i = 0; i < oQuantity; i ++) {
            user.doLimitOffer(wethAmount / oQuantity, weth, mkrAmount / oQuantity, mkr, false);
        }
    }

    function testProxyGetOffers() public {
        weth.mint(20 ether);
        weth.transfer(user, 20 ether);
        createOffers(1, 3200 ether, 10 ether);
        createOffers(1, 2800 ether, 10 ether);
        uint[100] memory ids;
        uint[100] memory sellAmts;
        uint[100] memory buyAmts;
        address[100] memory owners;
        uint[100] memory timestamps;
        (ids, sellAmts, buyAmts, owners, timestamps) = otcSupport.getOffers(OtcInterface(otc), weth, mkr);
        assertEq(ids[0], 2);
        assertEq(sellAmts[0], 10 ether);
        assertEq(buyAmts[0], 2800 ether);
        assertEq(owners[0], user);
        assertEq(ids[1], 1);
        assertEq(sellAmts[1], 10 ether);
        assertEq(buyAmts[1], 3200 ether);
        assertEq(owners[1], user);
        assertEq(owners[2], address(0));
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

    function testProxyGetOffersAmountToSellAllPartialOrderDust() public {
        weth.mint(20 ether);
        weth.transfer(user, 20 ether);
        createOffers(1, 3200 ether, 10 ether);
        createOffers(1, 800 ether, 4 ether);
        mkr.mint(4000 ether);
        mkr.approve(otcSupport, 4000 ether);
        uint offersToTake;
        bool takesPartialOrder;
        otc.setDustLimit(weth, 1); // 1 WETH => 320 MKR (worse offer price)
        (offersToTake, takesPartialOrder) = otcSupport.getOffersAmountToSellAll(OtcInterface(otc), mkr, 4000 ether - 320, weth);
        assertEq(offersToTake, 1);
        assertTrue(takesPartialOrder);
    }

    function testProxyGetOffersAmountToSellAllNoPartialOrderDust() public {
        weth.mint(20 ether);
        weth.transfer(user, 20 ether);
        createOffers(1, 3200 ether, 10 ether);
        createOffers(1, 800 ether, 4 ether);
        mkr.mint(4000 ether);
        mkr.approve(otcSupport, 4000 ether);
        uint offersToTake;
        bool takesPartialOrder;
        otc.setDustLimit(weth, 1); // 1 WETH => 320 MKR (worse offer price)
        (offersToTake, takesPartialOrder) = otcSupport.getOffersAmountToSellAll(OtcInterface(otc), mkr, 4000 ether - 319, weth);
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

    function testGetBuyAmount() public {
        weth.mint(20 ether);
        weth.transfer(user, 20 ether);
        createOffers(1, 3200 ether, 10 ether);
        createOffers(1, 2800 ether, 10 ether);
        assertEq(otcSupport.getBuyAmount(OtcInterface(otc), weth, mkr, 1400 ether), 5 ether);
        assertEq(otcSupport.getBuyAmount(OtcInterface(otc), weth, mkr, 4400 ether), 15 ether);
        assertEq(otcSupport.getBuyAmount(OtcInterface(otc), weth, mkr, 99999 ether), 20 ether);
    }

    function testGetPayAmount() public {
        weth.mint(20 ether);
        weth.transfer(user, 20 ether);
        createOffers(1, 3200 ether, 10 ether);
        createOffers(1, 2800 ether, 10 ether);
        assertEq(otcSupport.getPayAmount(OtcInterface(otc), mkr, weth, 5 ether), 1400 ether);
        assertEq(otcSupport.getPayAmount(OtcInterface(otc), mkr, weth, 15 ether), 4400 ether);
        assertEq(otcSupport.getPayAmount(OtcInterface(otc), mkr, weth, 999 ether), 6000 ether);
    }
}
