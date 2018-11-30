pragma solidity ^0.4.24;

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
    function dust(address) public view returns (uint);
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

    // event test(string, bool);
    // event test(string, uint);

    function getOffersAmountToSellAll(OtcInterface otc, address sellGem, uint sellAmt_, address buyGem) public view
        returns (uint offersToTake, bool takesPartialOffer)
    {
        uint offerId = otc.best(buyGem, sellGem);                                   // Get best offer for the token pair
        offersToTake = 0;
        uint sellAmt = sellAmt_;
        (uint oOfferSellAmt, uint oOfferBuyAmt, uint offerSellAmt,, uint offerBuyAmt,,,) = otc.offers(offerId);
        while (sellAmt > offerBuyAmt) {
            offersToTake ++;                                                        // New offer taken
            sellAmt = sub(sellAmt, offerBuyAmt);                                    // Decrease amount to sell
            if (sellAmt > 0) {                                                      // If we still need more offers
                offerId = otc.getWorseOffer(offerId);                               // We look for the next best offer
                require(offerId != 0, "No enough offers");                          // Fails if there are not enough offers to complete
                (oOfferSellAmt, oOfferBuyAmt, offerSellAmt,, offerBuyAmt,,,) = otc.offers(offerId);
            }
        }

        bool lastOfferFullTaken = sub(offerBuyAmt, sellAmt) == 0 ||
        mul(sub(offerBuyAmt, sellAmt), oOfferSellAmt) / oOfferBuyAmt < otc.dust(buyGem);

        // emit test("lastOfferFullTaken", lastOfferFullTaken);
        // emit test("offerBuyAmt - sellAmt", sub(offerBuyAmt, sellAmt));
        offersToTake = lastOfferFullTaken ? offersToTake + 1 : offersToTake;
        takesPartialOffer = sellAmt > 0 && !lastOfferFullTaken;
    }

    function getOffersAmountToBuyAll(OtcInterface otc, address buyGem, uint buyAmt_, address sellGem) public view
        returns (uint offersToTake, bool takesPartialOffer)
    {
        uint offerId = otc.best(buyGem, sellGem);                                   // Get best offer for the token pair
        offersToTake = 0;
        uint buyAmt = buyAmt_;
        (uint oOfferSellAmt, uint oOfferBuyAmt, uint offerSellAmt,, uint offerBuyAmt,,,) = otc.offers(offerId);
        while (buyAmt > offerSellAmt) {
            offersToTake ++;                                                        // New offer taken
            buyAmt = sub(buyAmt, offerSellAmt);                                     // Decrease amount to buy
            if (buyAmt > 0) {                                                       // If we still need more offers
                offerId = otc.getWorseOffer(offerId);                               // We look for the next best offer
                require(offerId != 0, "No enough offers");                          // Fails if there are not enough offers to complete
                (oOfferSellAmt, oOfferBuyAmt, offerSellAmt,, offerBuyAmt,,,) = otc.offers(offerId);
            }
        }

        bool lastOfferFullTaken = sub(offerSellAmt, buyAmt) == 0 ||
        sub(offerSellAmt, buyAmt) < otc.dust(buyGem);

        offersToTake = lastOfferFullTaken ? offersToTake + 1 : offersToTake;
        takesPartialOffer = buyAmt > 0 && !lastOfferFullTaken;
    }

    function getBuyAmount(OtcInterface otc, address buy_gem, address pay_gem, uint pay_amt) public view returns (uint fill_amt) {
        uint offerId = otc.best(buy_gem, pay_gem);                                  // Get best offer for the token pair
        require(offerId != 0);
        (uint oSellAmt, uint oBuyAmt, uint sellAmt, , uint buyAmt, , , ) = otc.offers(offerId);
        while (pay_amt > buyAmt) {
            fill_amt = add(fill_amt, sellAmt);                                      // Add amount to buy accumulator
            pay_amt = sub(pay_amt, buyAmt);                                         // Decrease amount to pay
            if (pay_amt > 0) {                                                      // If we still need more offers
                offerId = otc.getWorseOffer(offerId);                               // We look for the next best offer
                if (offerId == 0)
                    return;                                                         // Return everything if there are not enough offers to complete
                (oSellAmt, oBuyAmt, sellAmt, , buyAmt, , , ) = otc.offers(offerId);
            }
        }
        fill_amt = add(fill_amt, rmul(pay_amt * 10 ** 9, rdiv(sellAmt, buyAmt)) / 10 ** 9); // Add proportional amount of last offer to buy accumulator
    }

    function getPayAmount(OtcInterface otc, address pay_gem, address buy_gem, uint buy_amt) public view returns (uint fill_amt) {
        uint offerId = otc.best(buy_gem, pay_gem);                                  // Get best offer for the token pair
        require(offerId != 0);
        (uint oSellAmt, uint oBuyAmt, uint sellAmt, , uint buyAmt, , , ) = otc.offers(offerId);
        while (buy_amt > sellAmt) {
            fill_amt = add(fill_amt, buyAmt);                                       // Add amount to pay accumulator
            buy_amt = sub(buy_amt, sellAmt);                                        // Decrease amount to buy
            if (buy_amt > 0) {                                                      // If we still need more offers
                offerId = otc.getWorseOffer(offerId);                               // We look for the next best offer
                if (offerId == 0)
                    return;                                                         // Return everything if there are not enough offers to complete
                (oSellAmt, oBuyAmt, sellAmt, , buyAmt, , , ) = otc.offers(offerId);
            }
        }
        fill_amt = add(fill_amt, rmul(buy_amt * 10 ** 9, rdiv(buyAmt, sellAmt)) / 10 ** 9); // Add proportional amount of last offer to pay accumulator
    }

}
