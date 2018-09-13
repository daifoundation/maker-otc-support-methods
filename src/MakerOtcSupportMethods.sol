pragma solidity ^0.4.23;

import "ds-math/math.sol";

contract OtcInterface {
    struct OfferInfo {
        uint     oSellAmt;
        uint     oBuyAmt;
        uint     sellAmt;
        address  sellGem;
        uint     buyAmt;
        address  buyGem;
        address  owner;
        uint64   timestamp;
    }
    mapping (uint => OfferInfo) public offers;
    function best(address, address) public view returns (uint);
    function getWorseOffer(uint) public view returns (uint);
}

contract MakerOtcSupportMethods is DSMath {
    function getOffers(OtcInterface otc, address payToken, address buyToken) public view
        returns (uint[100] ids, uint[100] payAmts, uint[100] buyAmts, address[100] owners, uint[100] timestamps)
    {
        (ids, payAmts, buyAmts, owners, timestamps) = getOffers(otc, otc.best(payToken, buyToken));
    }

    function getOffers(OtcInterface otc, uint offerId_) public view
        returns (uint[100] ids, uint[100] payAmts, uint[100] buyAmts, address[100] owners, uint[100] timestamps)
    {
        uint offerId = offerId_;
        uint i = 0;
        do {
            (,,payAmts[i],, buyAmts[i],, owners[i], timestamps[i]) = otc.offers(offerId);
            if(owners[i] == 0) break;
            ids[i] = offerId;
            offerId = otc.getWorseOffer(offerId);
        } while (++i < 100);
    }

    function getOffersAmountToSellAll(OtcInterface otc, address payToken, uint payAmt, address buyToken) public view
        returns (uint ordersToTake, bool takesPartialOrder)
    {
        uint offerId = otc.best(buyToken, payToken);                                // Get best offer for the token pair
        ordersToTake = 0;
        uint payAmt2 = payAmt;
        uint orderBuyAmt = 0;
        (,,,,orderBuyAmt,,,) = otc.offers(offerId);
        while (payAmt2 > orderBuyAmt) {
            ordersToTake ++;                                                        // New order taken
            payAmt2 = sub(payAmt2, orderBuyAmt);                                    // Decrease amount to pay
            if (payAmt2 > 0) {                                                      // If we still need more offers
                offerId = otc.getWorseOffer(offerId);                               // We look for the next best offer
                require(offerId != 0, "No enough orders");                          // Fails if there are not enough offers to complete
                (,,,,orderBuyAmt,,,) = otc.offers(offerId);
            }
            
        }
        // If the remaining amount is equal than the latest order, then it will also be taken completely
        ordersToTake = payAmt2 == orderBuyAmt ? ordersToTake + 1 : ordersToTake;
        // If the remaining amount is lower than the latest order, then it will take a partial order
        takesPartialOrder = payAmt2 < orderBuyAmt;
    }

    function getOffersAmountToBuyAll(OtcInterface otc, address buyToken, uint buyAmt, address payToken) public view
        returns (uint ordersToTake, bool takesPartialOrder)
    {
        uint offerId = otc.best(buyToken, payToken);                                // Get best offer for the token pair
        ordersToTake = 0;
        uint buyAmt2 = buyAmt;
        uint orderPayAmt = 0;
        (,,orderPayAmt,,,,,) = otc.offers(offerId);
        while (buyAmt2 > orderPayAmt) {
            ordersToTake ++;                                                        // New order taken
            buyAmt2 = sub(buyAmt2, orderPayAmt);                                    // Decrease amount to buy
            if (buyAmt2 > 0) {                                                      // If we still need more offers
                offerId = otc.getWorseOffer(offerId);                               // We look for the next best offer
                require(offerId != 0, "No enough orders");                          // Fails if there are not enough offers to complete
                (,,orderPayAmt,,,,,) = otc.offers(offerId);
            }
        }
        // If the remaining amount is equal than the latest order, then it will also be taken completely
        ordersToTake = buyAmt2 == orderPayAmt ? ordersToTake + 1 : ordersToTake;
        // If the remaining amount is lower than the latest order, then it will take a partial order
        takesPartialOrder = buyAmt2 < orderPayAmt;
    }
}
