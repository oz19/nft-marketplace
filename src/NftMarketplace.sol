// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.34;

import "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC721/IERC721.sol";


contract NftMarketplace is Ownable {

    struct Listing {
        address seller;
        address nftCollection;
        uint256 tokenId;
        uint256 price;
    }

    mapping(address => mapping(uint256 => Listing)) listings;

    event NftListed(Listing);

    constructor () Ownable(msg.sender) {

    }

    function listNft(address nftCollection_, uint256 tokenId_, uint256 price_) external {

        require(price_ > 0, "Price must be higher than 0");
        
        address tokenOwner_ = IERC721(nftCollection_).ownerOf(tokenId_);
        require(tokenOwner_ == msg.sender, "You are not the NFT owner");

        Listing memory listing_ = Listing({
            seller: msg.sender,
            nftCollection: nftCollection_,
            tokenId: tokenId_,
            price: price_
        });

        listings[nftCollection_][tokenId_] = listing_;

        emit NftListed(listing_);

    }

}