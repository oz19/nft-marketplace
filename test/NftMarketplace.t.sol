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
    uint256 firstTokenId = 0;
    
    function setUp() public {
        vm.startPrank(deployer);
        marketplace = new NftMarketplace();
        vm.stopPrank();

        vm.startPrank(user);
        mockNft = new MockNft();
        mockNft.mint(user, firstTokenId);
        vm.stopPrank();

    }

    function testMintNft() public view {
        address owner_ = mockNft.ownerOf(firstTokenId);
        assert(owner_ == user);
    }
}