pragma solidity >=0.4.23;

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
        ERC20(token).approve(address(otc), uint(-1));
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
        weth.approve(address(otc));
        mkr.approve(address(otc));
        user = new FakeUser(otc);
        user.doApprove(address(weth));
        user.doApprove(address(mkr));
    }

    function createOffers(uint oQuantity, uint mkrAmount, uint wethAmount) public {
        for (uint i = 0; i < oQuantity; i ++) {
            user.doLimitOffer(wethAmount / oQuantity, address(weth), mkrAmount / oQuantity, address(mkr), false);
        }
    }

    function testProxyGetOffers() public {
        weth.mint(20 ether);
        weth.transfer(address(user), 20 ether);
        createOffers(1, 3200 ether, 10 ether);
        createOffers(1, 2800 ether, 10 ether);
        uint[100] memory ids;
        uint[100] memory sellAmts;
        uint[100] memory buyAmts;
        address[100] memory owners;
        uint[100] memory timestamps;
        (ids, sellAmts, buyAmts, owners, timestamps) = otcSupport.getOffers(OtcInterface(address(otc)), address(weth), address(mkr));
        assertEq(ids[0], 2);
        assertEq(sellAmts[0], 10 ether);
        assertEq(buyAmts[0], 2800 ether);
        assertEq(owners[0], address(user));
        assertEq(ids[1], 1);
        assertEq(sellAmts[1], 10 ether);
        assertEq(buyAmts[1], 3200 ether);
        assertEq(owners[1], address(user));
        assertEq(owners[2], address(0));
    }

    function testProxyGetOffersAmountToSellAllPartialOrder() public {
        weth.mint(20 ether);
        weth.transfer(address(user), 20 ether);
        createOffers(1, 3200 ether, 10 ether);
        createOffers(1, 2800 ether, 10 ether);
        mkr.mint(4000 ether);
        mkr.approve(address(otcSupport), 4000 ether);
        uint offersToTake;
        bool takesPartialOrder;
        (offersToTake, takesPartialOrder) = otcSupport.getOffersAmountToSellAll(OtcInterface(address(otc)), address(mkr), 4000 ether, address(weth));
        assertEq(offersToTake, 1);
        assertTrue(takesPartialOrder);
    }

    function testProxyGetOffersAmountToSellAllNoPartialOrder() public {
        weth.mint(20 ether);
        weth.transfer(address(user), 20 ether);
        createOffers(1, 3200 ether, 10 ether);
        createOffers(1, 800 ether, 4 ether);
        mkr.mint(4000 ether);
        mkr.approve(address(otcSupport), 4000 ether);
        uint offersToTake;
        bool takesPartialOrder;
        (offersToTake, takesPartialOrder) = otcSupport.getOffersAmountToSellAll(OtcInterface(address(otc)), address(mkr), 4000 ether, address(weth));
        assertEq(offersToTake, 2);
        assertTrue(!takesPartialOrder);
    }

    function testProxyGetOffersAmountToSellAllPartialOrderDust() public {
        weth.mint(20 ether);
        weth.transfer(address(user), 20 ether);
        createOffers(1, 3200 ether, 10 ether);
        createOffers(1, 800 ether, 4 ether);
        mkr.mint(4000 ether);
        mkr.approve(address(otcSupport), 4000 ether);
        uint offersToTake;
        bool takesPartialOrder;
        otc.setDustLimit(address(weth), 1); // 1 WETH => 320 MKR (worse offer price)
        (offersToTake, takesPartialOrder) = otcSupport.getOffersAmountToSellAll(OtcInterface(address(otc)), address(mkr), 4000 ether - 320, address(weth));
        assertEq(offersToTake, 1);
        assertTrue(takesPartialOrder);
    }

    function testProxyGetOffersAmountToSellAllNoPartialOrderDust() public {
        weth.mint(20 ether);
        weth.transfer(address(user), 20 ether);
        createOffers(1, 3200 ether, 10 ether);
        createOffers(1, 800 ether, 4 ether);
        mkr.mint(4000 ether);
        mkr.approve(address(otcSupport), 4000 ether);
        uint offersToTake;
        bool takesPartialOrder;
        otc.setDustLimit(address(weth), 1); // 1 WETH => 320 MKR (worse offer price)
        (offersToTake, takesPartialOrder) = otcSupport.getOffersAmountToSellAll(OtcInterface(address(otc)), address(mkr), 4000 ether - 319, address(weth));
        assertEq(offersToTake, 2);
        assertTrue(!takesPartialOrder);
    }

    function testProxyGetOffersAmountToBuyAllPartialOrder() public {
        weth.mint(20 ether);
        weth.transfer(address(user), 20 ether);
        createOffers(1, 3200 ether, 10 ether);
        createOffers(1, 2800 ether, 10 ether);
        mkr.mint(4400 ether);
        mkr.approve(address(otcSupport), 4400 ether);
        uint offersToTake;
        bool takesPartialOrder;
        (offersToTake, takesPartialOrder) = otcSupport.getOffersAmountToBuyAll(OtcInterface(address(otc)), address(weth), 15 ether, address(mkr));
        assertEq(offersToTake, 1);
        assertTrue(takesPartialOrder);
    }

    function testProxyGetOffersAmountToBuyAllNoPartialOrder() public {
        weth.mint(15 ether);
        weth.transfer(address(user), 15 ether);
        createOffers(1, 3200 ether, 10 ether);
        createOffers(1, 2800 ether, 5 ether);
        mkr.mint(4400 ether);
        mkr.approve(address(otcSupport), 4400 ether);
        uint offersToTake;
        bool takesPartialOrder;
        (offersToTake, takesPartialOrder) = otcSupport.getOffersAmountToBuyAll(OtcInterface(address(otc)), address(weth), 15 ether, address(mkr));
        assertEq(offersToTake, 2);
        assertTrue(!takesPartialOrder);
    }

    function testGetBuyAmount() public {
        weth.mint(20 ether);
        weth.transfer(address(user), 20 ether);
        createOffers(1, 3200 ether, 10 ether);
        createOffers(1, 2800 ether, 10 ether);
        assertEq(otcSupport.getBuyAmount(OtcInterface(address(otc)), address(weth), address(mkr), 1400 ether), 5 ether);
        assertEq(otcSupport.getBuyAmount(OtcInterface(address(otc)), address(weth), address(mkr), 4400 ether), 15 ether);
    }

    function testGetPayAmount() public {
        weth.mint(20 ether);
        weth.transfer(address(user), 20 ether);
        createOffers(1, 3200 ether, 10 ether);
        createOffers(1, 2800 ether, 10 ether);
        assertEq(otcSupport.getPayAmount(OtcInterface(address(otc)), address(mkr), address(weth), 5 ether), 1400 ether);
        assertEq(otcSupport.getPayAmount(OtcInterface(address(otc)), address(mkr), address(weth), 15 ether), 4400 ether);
    }
}
