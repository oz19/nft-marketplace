// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

import "forge-std/Test.sol";
import "../src/NftMarketplace.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC721/ERC721.sol";


contract MockNft is ERC721 {

    constructor() ERC721("Mock NFT", "MNFT") {}

    function mint(address to_, uint256 tokenId_) external {
        _mint(to_, tokenId_);
    }

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

    function testNftListingWorksCorrectly() public {
        vm.startPrank(user);

        uint256 price_ = 10;

        (address sellerBefore,,,) = marketplace.listings(address(mockNft), tokenId);
        marketplace.listNft(address(mockNft), tokenId, price_);
        (address sellerAfter,,,) = marketplace.listings(address(mockNft), tokenId);
        
        assert(sellerBefore == address(0));
        assert(sellerAfter == user);

        vm.stopPrank();
    }

    function testCancelNftListingFailsIfNotRequestedByOwner() public {
        vm.startPrank(user);
        
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

        marketplace.listNft(address(mockNft), tokenId, 10);

        (address sellerBefore,,, uint256 price) = marketplace.listings(address(mockNft), tokenId);
        assert(sellerBefore == user);
        assert(price == 10);

        marketplace.cancelNftListing(address(mockNft), tokenId);

        (address sellerAfter,,,) = marketplace.listings(address(mockNft), tokenId);
        assert(sellerAfter == address(0));

        vm.stopPrank();
    }
}