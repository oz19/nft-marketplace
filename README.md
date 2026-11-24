# NFT Marketplace

A peer-to-peer marketplace for buying and selling ERC721 NFTs at fixed prices. Sellers list their NFTs, and buyers purchase them by sending the exact listed price. Payment is forwarded directly to the seller on purchase.

## Contract

`NftMarketplace.sol` — no upgradability, no fees, no escrow.

| Function | Access | Description |
|---|---|---|
| `listNft(collection, tokenId, price)` | public | Lists an NFT for sale. Requires marketplace approval and ownership. |
| `cancelNftListing(collection, tokenId)` | seller only | Removes an active listing. |
| `buyNft(collection, tokenId)` | public payable | Purchases a listed NFT. Must send exact price in ETH. |

## Flow

```
Seller:  approve(marketplace, tokenId)
         → listNft(collection, tokenId, price)

Buyer:   buyNft{value: price}(collection, tokenId)
         → NFT transferred to buyer
         → ETH forwarded to seller
```

## Security notes

- Follows the **CEI pattern** (Checks-Effects-Interactions) in `buyNft`: listing is deleted before any external calls.
- `buyNft` is protected with `ReentrancyGuard`.
- Approval is verified at listing time to prevent ghost listings that would revert at purchase.
- `mint()` is unrestricted on `StakingToken` — do not use in production.

## Usage

```shell
# Build
forge build

# Run tests
forge test

# Coverage report (src/NftMarketplace.sol: 100%)
forge coverage
```
