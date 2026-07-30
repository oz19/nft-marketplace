// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.34;

import "../lib/openzeppelin-contracts/contracts/token/ERC721/IERC721.sol";
import "../lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";


contract NftMarketplace is ReentrancyGuard {

    struct Listing {
        address seller;
        address nftCollection;
        uint256 tokenId;
        uint256 price;
    }

    mapping(address => mapping(uint256 => Listing)) public listings;

    event NftListed(address indexed seller, address indexed nftCollection, uint256 indexed tokenId, uint256 price);
    event NftListingCancelled(address indexed seller, address indexed nftCollection, uint256 indexed tokenId);
    event NftSold(address indexed buyer, address indexed seller, address indexed nftCollection, uint256 tokenId, uint256 price);


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

        emit NftListed(listing_.seller, listing_.nftCollection, listing_.tokenId, listing_.price);

    }

    function cancelNftListing(address nftCollection_, uint256 tokenId_) external {
        Listing memory listing_ = listings[nftCollection_][tokenId_];
        require(listing_.seller == msg.sender, "You are not the owner");

        delete listings[nftCollection_][tokenId_];

        emit NftListingCancelled(listing_.seller, listing_.nftCollection, listing_.tokenId);
    }

    function buyNft(address nftCollection_, uint256 tokenId_) external payable nonReentrant {
        Listing memory listing_ = listings[nftCollection_][tokenId_];
        require(listing_.nftCollection != address(0), "That NFT is not listed");
        require(msg.value == listing_.price, "Incorrect price");

        delete listings[nftCollection_][tokenId_];

        IERC721(nftCollection_).safeTransferFrom(listing_.seller, msg.sender, tokenId_);

        (bool success, ) = listing_.seller.call{value: listing_.price}("");
        require(success, "Transfer failed");

        emit NftSold(msg.sender, listing_.seller, listing_.nftCollection, listing_.tokenId, listing_.price);
    }

}