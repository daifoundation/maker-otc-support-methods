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
    function getOffers(OtcInterface otc, address sellGem, address buyGem) public view
        returns (uint[100] ids, uint[100] sellAmts, uint[100] buyAmts, address[100] owners, uint[100] timestamps)
    {
        (ids, sellAmts, buyAmts, owners, timestamps) = getOffers(otc, otc.best(sellGem, buyGem));
    }

    function getOffers(OtcInterface otc, uint offerId_) public view
        returns (uint[100] ids, uint[100] sellAmts, uint[100] buyAmts, address[100] owners, uint[100] timestamps)
    {
        uint offerId = offerId_;
        uint i = 0;
        do {
            (,,sellAmts[i],, buyAmts[i],, owners[i], timestamps[i]) = otc.offers(offerId);
            if(owners[i] == 0) break;
            ids[i] = offerId;
            offerId = otc.getWorseOffer(offerId);
        } while (++i < 100);
    }

    function getOffersAmountToSellAll(OtcInterface otc, address sellGem, uint sellAmt_, address buyGem) public view
        returns (uint offersToTake, bool takesPartialOffer)
    {
        uint offerId = otc.best(buyGem, sellGem);                                   // Get best offer for the token pair
        offersToTake = 0;
        uint sellAmt = sellAmt_;
        uint offerBuyAmt = 0;
        (,,,,offerBuyAmt,,,) = otc.offers(offerId);
        while (sellAmt > offerBuyAmt) {
            offersToTake ++;                                                        // New offer taken
            sellAmt = sub(sellAmt, offerBuyAmt);                                    // Decrease amount to sell
            if (sellAmt > 0) {                                                      // If we still need more offers
                offerId = otc.getWorseOffer(offerId);                               // We look for the next best offer
                require(offerId != 0, "No enough offers");                          // Fails if there are not enough offers to complete
                (,,,,offerBuyAmt,,,) = otc.offers(offerId);
            }
        }
        // If the remaining amount is equal than the latest offer, then it will also be taken completely
        offersToTake = sellAmt == offerBuyAmt ? offersToTake + 1 : offersToTake;
        // If the remaining amount is lower than the latest offer, then it will take a partial offer
        takesPartialOffer = sellAmt < offerBuyAmt;
    }

    function getOffersAmountToBuyAll(OtcInterface otc, address buyGem, uint buyAmt_, address sellGem) public view
        returns (uint offersToTake, bool takesPartialOffer)
    {
        uint offerId = otc.best(buyGem, sellGem);                                   // Get best offer for the token pair
        offersToTake = 0;
        uint buyAmt = buyAmt_;
        uint offerSellAmt = 0;
        (,,offerSellAmt,,,,,) = otc.offers(offerId);
        while (buyAmt > offerSellAmt) {
            offersToTake ++;                                                        // New offer taken
            buyAmt = sub(buyAmt, offerSellAmt);                                     // Decrease amount to buy
            if (buyAmt > 0) {                                                       // If we still need more offers
                offerId = otc.getWorseOffer(offerId);                               // We look for the next best offer
                require(offerId != 0, "No enough offers");                          // Fails if there are not enough offers to complete
                (,,offerSellAmt,,,,,) = otc.offers(offerId);
            }
        }
        // If the remaining amount is equal than the latest offer, then it will also be taken completely
        offersToTake = buyAmt == offerSellAmt ? offersToTake + 1 : offersToTake;
        // If the remaining amount is lower than the latest offer, then it will take a partial offer
        takesPartialOffer = buyAmt < offerSellAmt;
    }
}
