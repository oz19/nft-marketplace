// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.34;

import "../lib/openzeppelin-contracts/contracts/token/ERC721/IERC721.sol";
import "../lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";

/**
 * @title NftMarketplace
 * @notice Peer-to-peer marketplace for buying and selling ERC721 NFTs at fixed prices.
 * @dev Payments are forwarded directly to the seller on purchase.
 *      Uses ReentrancyGuard on buyNft to prevent reentrancy attacks.
 */
contract NftMarketplace is ReentrancyGuard {

    /**
     * @notice Represents an active NFT listing.
     * @param seller The address that created the listing.
     * @param nftCollection The ERC721 contract address.
     * @param tokenId The token ID being sold.
     * @param price The fixed sale price in wei.
     */
    struct Listing {
        address seller;
        address nftCollection;
        uint256 tokenId;
        uint256 price;
    }

    /// @notice Active listings indexed by collection address and token ID.
    mapping(address => mapping(uint256 => Listing)) public listings;

    /**
     * @notice Emitted when an NFT is listed for sale.
     * @param seller The address listing the NFT.
     * @param nftCollection The ERC721 contract address.
     * @param tokenId The token ID listed.
     * @param price The listing price in wei.
     */
    event NftListed(address indexed seller, address indexed nftCollection, uint256 indexed tokenId, uint256 price);

    /**
     * @notice Emitted when a listing is cancelled by the seller.
     * @param seller The address that cancelled the listing.
     * @param nftCollection The ERC721 contract address.
     * @param tokenId The token ID whose listing was cancelled.
     */
    event NftListingCancelled(address indexed seller, address indexed nftCollection, uint256 indexed tokenId);

    /**
     * @notice Emitted when an NFT is sold.
     * @param buyer The address that bought the NFT.
     * @param seller The address that sold the NFT.
     * @param nftCollection The ERC721 contract address.
     * @param tokenId The token ID sold.
     * @param price The price paid in wei.
     */
    event NftSold(address indexed buyer, address indexed seller, address indexed nftCollection, uint256 tokenId, uint256 price);

    /**
     * @notice Lists an NFT for sale at a fixed price.
     * @dev The marketplace must be approved to transfer the token before listing.
     *      Verifies ownership and approval to prevent ghost listings.
     * @param nftCollection_ The ERC721 contract address.
     * @param tokenId_ The token ID to list.
     * @param price_ The sale price in wei. Must be greater than zero.
     */
    function listNft(address nftCollection_, uint256 tokenId_, uint256 price_) external {
        require(price_ > 0, "Price must be higher than 0");

        address tokenOwner_ = IERC721(nftCollection_).ownerOf(tokenId_);
        require(tokenOwner_ == msg.sender, "You are not the NFT owner");

        bool isApproved = IERC721(nftCollection_).getApproved(tokenId_) == address(this)
            || IERC721(nftCollection_).isApprovedForAll(msg.sender, address(this));
        require(isApproved, "Marketplace not approved for this token");

        Listing memory listing_ = Listing({
            seller: msg.sender,
            nftCollection: nftCollection_,
            tokenId: tokenId_,
            price: price_
        });

        listings[nftCollection_][tokenId_] = listing_;

        emit NftListed(listing_.seller, listing_.nftCollection, listing_.tokenId, listing_.price);
    }

    /**
     * @notice Cancels an active listing. Only callable by the original seller.
     * @param nftCollection_ The ERC721 contract address.
     * @param tokenId_ The token ID whose listing to cancel.
     */
    function cancelNftListing(address nftCollection_, uint256 tokenId_) external {
        Listing memory listing_ = listings[nftCollection_][tokenId_];
        require(listing_.seller == msg.sender, "You are not the owner");

        delete listings[nftCollection_][tokenId_];

        emit NftListingCancelled(listing_.seller, listing_.nftCollection, listing_.tokenId);
    }

    /**
     * @notice Purchases a listed NFT by sending the exact listed price.
     * @dev Deletes the listing before transferring assets (CEI pattern).
     *      Protected against reentrancy via ReentrancyGuard.
     * @param nftCollection_ The ERC721 contract address.
     * @param tokenId_ The token ID to purchase.
     */
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
