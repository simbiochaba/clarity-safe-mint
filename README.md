# SafeMint

A no-code platform for creating secure NFTs on the Stacks blockchain. This contract provides a secure and standardized way to create and manage NFT collections without requiring coding knowledge.

## Features

- Create NFT collections with customizable properties
- Mint NFTs with guaranteed uniqueness 
- Built-in royalty support
- Transfer and ownership management
- Collection metadata management
- Access control and admin functions

### Secondary Market Features

- List NFTs for sale with customizable prices
- Automated royalty payments to collection creators
- Floor price enforcement for collections
- Secure token transfers with listing state validation
- Built-in marketplace functionality

## Security Features

- Standardized minting process to prevent duplicates
- Access control for administrative functions
- Immutable collection properties once set
- Safe transfer mechanisms
- Protected secondary market transactions
- Automated royalty distribution

## Secondary Market Usage

To participate in the secondary market:

1. List an NFT:
```clarity
(contract-call? .safe-mint list-token collection-id token-id price)
```

2. Buy a listed NFT:
```clarity
(contract-call? .safe-mint buy-token collection-id token-id)
```

3. Unlist an NFT:
```clarity
(contract-call? .safe-mint unlist-token collection-id token-id)
```

Royalties are automatically calculated and distributed to collection creators during sales.
