// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

import "forge-std/Test.sol";
import "../src/NftMarketplace.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC721/ERC721.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC721/IERC721Receiver.sol";


contract MockNft is ERC721 {

    constructor() ERC721("Mock NFT", "MNFT") {}

    function mint(address to_, uint256 tokenId_) external {
        _mint(to_, tokenId_);
    }

}

/// @dev Seller contract that rejects ETH to trigger the transfer failure branch in buyNft.
contract MaliciousSeller is IERC721Receiver {

    NftMarketplace public marketplace;
    MockNft public nft;

    constructor(address marketplace_, address nft_) {
        marketplace = NftMarketplace(marketplace_);
        nft = MockNft(nft_);
    }

    function listToken(uint256 tokenId_, uint256 price_) external {
        nft.approve(address(marketplace), tokenId_);
        marketplace.listNft(address(nft), tokenId_, price_);
    }

    function onERC721Received(address, address, uint256, bytes calldata) external pure override returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }

    // No receive() — rejects ETH, causing buyNft's seller payment to fail.

}


contract TestNftMarketplace is Test {

    NftMarketplace marketplace;
    address deployer = vm.addr(1);
    address user = vm.addr(2);
    MockNft mockNft;
    uint256 tokenId = 0;

    function setUp() public {
        vm.startPrank(deployer);
        marketplace = new NftMarketplace();
        vm.stopPrank();

        vm.startPrank(user);
        mockNft = new MockNft();
        mockNft.mint(user, tokenId);
        vm.stopPrank();
    }

    function testMintNft() public view {
        address owner_ = mockNft.ownerOf(tokenId);
        assert(owner_ == user);
    }

    function testNftListingFailsWhenPriceIsZero() public {
        vm.startPrank(user);

        uint256 price_ = 0;

        vm.expectRevert("Price must be higher than 0");
        marketplace.listNft(address(mockNft), tokenId, price_);

        vm.stopPrank();
    }

    function testNftListingFailsWhenNotRequestedByOwner() public {
        address notTheOwner = vm.addr(3);
        vm.startPrank(notTheOwner);

        uint256 price_ = 10;

        vm.expectRevert("You are not the NFT owner");
        marketplace.listNft(address(mockNft), tokenId, price_);

        vm.stopPrank();
    }

    function testNftListingFailsWhenMarketplaceNotApproved() public {
        vm.startPrank(user);

        vm.expectRevert("Marketplace not approved for this token");
        marketplace.listNft(address(mockNft), tokenId, 10);

        vm.stopPrank();
    }

    function testNftListingWorksCorrectly() public {
        vm.startPrank(user);

        uint256 price_ = 10;
        mockNft.approve(address(marketplace), tokenId);

        (address sellerBefore,,,) = marketplace.listings(address(mockNft), tokenId);
        marketplace.listNft(address(mockNft), tokenId, price_);
        (address sellerAfter,,,) = marketplace.listings(address(mockNft), tokenId);

        assert(sellerBefore == address(0));
        assert(sellerAfter == user);

        vm.stopPrank();
    }

    function testCancelNftListingFailsIfNotRequestedByOwner() public {
        vm.startPrank(user);

        mockNft.approve(address(marketplace), tokenId);
        marketplace.listNft(address(mockNft), tokenId, 10);

        (address seller,,, uint256 price) = marketplace.listings(address(mockNft), tokenId);
        assert(seller == user);
        assert(price == 10);

        vm.stopPrank();

        address notTheOwner = vm.addr(3);
        vm.startPrank(notTheOwner);

        vm.expectRevert("You are not the owner");
        marketplace.cancelNftListing(address(mockNft), tokenId);

        vm.stopPrank();
    }

    function testCancelNftListingWorksCorrectly() public {
        vm.startPrank(user);

        mockNft.approve(address(marketplace), tokenId);
        marketplace.listNft(address(mockNft), tokenId, 10);

        (address sellerBefore,,, uint256 price) = marketplace.listings(address(mockNft), tokenId);
        assert(sellerBefore == user);
        assert(price == 10);

        marketplace.cancelNftListing(address(mockNft), tokenId);

        (address sellerAfter,,,) = marketplace.listings(address(mockNft), tokenId);
        assert(sellerAfter == address(0));

        vm.stopPrank();
    }

    function testTryingToBuyNonListedNftShouldRevert() public {
        address buyer = vm.addr(3);
        vm.startPrank(buyer);

        vm.expectRevert("That NFT is not listed");
        marketplace.buyNft(address(mockNft), tokenId);

        vm.stopPrank();
    }

    function testPayingDifferentPriceShouldRevert() public {
        vm.startPrank(user);

        uint256 price = 10;
        mockNft.approve(address(marketplace), tokenId);
        (address sellerBefore,,,) = marketplace.listings(address(mockNft), tokenId);
        marketplace.listNft(address(mockNft), tokenId, price);
        (address sellerAfter,,,) = marketplace.listings(address(mockNft), tokenId);

        assert(sellerBefore == address(0) && sellerAfter == user);

        vm.stopPrank();

        address buyer = vm.addr(3);
        vm.startPrank(buyer);

        vm.deal(buyer, price - 1);
        vm.expectRevert("Incorrect price");
        marketplace.buyNft{value: price - 1}(address(mockNft), tokenId);

        vm.stopPrank();
    }

    function testBuyNftEthTransferToSellerFails() public {
        MaliciousSeller seller = new MaliciousSeller(address(marketplace), address(mockNft));

        vm.prank(user);
        mockNft.transferFrom(user, address(seller), tokenId);

        seller.listToken(tokenId, 10);

        address buyer = vm.addr(3);
        vm.deal(buyer, 10);
        vm.startPrank(buyer);

        vm.expectRevert("Transfer failed");
        marketplace.buyNft{value: 10}(address(mockNft), tokenId);

        vm.stopPrank();
    }

    function testBuyNftWorksCorrectly() public {
        vm.startPrank(user);

        mockNft.approve(address(marketplace), tokenId);

        uint256 price = 10;
        (address sellerBefore,,,) = marketplace.listings(address(mockNft), tokenId);
        marketplace.listNft(address(mockNft), tokenId, price);
        (address sellerAfter,,,) = marketplace.listings(address(mockNft), tokenId);

        assert(sellerBefore == address(0) && sellerAfter == user);

        vm.stopPrank();

        address buyer = vm.addr(3);
        vm.startPrank(buyer);
        vm.deal(buyer, price);

        uint256 userBalanceBefore = user.balance;
        (address sellerBeforeSale,,,) = marketplace.listings(address(mockNft), tokenId);
        address oldOwner = mockNft.ownerOf(tokenId);

        marketplace.buyNft{value: price}(address(mockNft), tokenId);

        uint256 userBalanceAfter = user.balance;
        assert(userBalanceAfter - userBalanceBefore == price);

        (address sellerAfterSale,,,) = marketplace.listings(address(mockNft), tokenId);
        assert(sellerBeforeSale == user && sellerAfterSale == address(0));

        address newOwner = mockNft.ownerOf(tokenId);
        assert(oldOwner == user && newOwner == buyer);

        vm.stopPrank();
    }

}
