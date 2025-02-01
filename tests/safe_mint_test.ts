import {
  Clarinet,
  Tx,
  Chain,
  Account,
  types
} from 'https://deno.land/x/clarinet@v1.0.0/index.ts';
import { assertEquals } from 'https://deno.land/std@0.90.0/testing/asserts.ts';

Clarinet.test({
    name: "Can create a new collection",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const wallet_1 = accounts.get('wallet_1')!;
        
        let block = chain.mineBlock([
            Tx.contractCall('safe-mint', 'create-collection', [
                types.ascii("Test Collection"),
                types.ascii("TEST"),
                types.utf8("ipfs://metadata"),
                types.uint(5), // 5% royalty
                types.uint(1000), // max supply
                types.uint(100000000) // floor price 100 STX
            ], wallet_1.address)
        ]);
        
        block.receipts[0].result.expectOk().expectUint(1);
        
        // Verify collection info
        let collection = chain.callReadOnlyFn(
            'safe-mint',
            'get-collection-info',
            [types.uint(1)],
            wallet_1.address
        );
        
        let collectionData = collection.result.expectSome().expectTuple();
        assertEquals(collectionData['name'], "Test Collection");
    }
});

Clarinet.test({
    name: "Can mint and list NFT",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const wallet_1 = accounts.get('wallet_1')!;
        
        // Create collection
        let block = chain.mineBlock([
            Tx.contractCall('safe-mint', 'create-collection', [
                types.ascii("Test Collection"),
                types.ascii("TEST"),
                types.utf8("ipfs://metadata"),
                types.uint(5),
                types.uint(1000),
                types.uint(100000000)
            ], wallet_1.address),
            
            // Mint token
            Tx.contractCall('safe-mint', 'mint', [
                types.uint(1),
                types.utf8("ipfs://token-metadata")
            ], wallet_1.address),
            
            // List token
            Tx.contractCall('safe-mint', 'list-token', [
                types.uint(1),
                types.uint(1),
                types.uint(150000000)
            ], wallet_1.address)
        ]);
        
        block.receipts[2].result.expectOk().expectBool(true);
        
        // Verify listing
        let tokenInfo = chain.callReadOnlyFn(
            'safe-mint',
            'get-token-info',
            [types.uint(1), types.uint(1)],
            wallet_1.address
        );
        
        let tokenData = tokenInfo.result.expectSome().expectTuple();
        assertEquals(tokenData['listed'], true);
        assertEquals(tokenData['price'], 150000000);
    }
});

Clarinet.test({
    name: "Can buy listed NFT with royalties",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const wallet_1 = accounts.get('wallet_1')!;
        const wallet_2 = accounts.get('wallet_2')!;
        
        // Setup collection and token
        let block = chain.mineBlock([
            Tx.contractCall('safe-mint', 'create-collection', [
                types.ascii("Test Collection"),
                types.ascii("TEST"),
                types.utf8("ipfs://metadata"),
                types.uint(5),
                types.uint(1000),
                types.uint(100000000)
            ], wallet_1.address),
            
            Tx.contractCall('safe-mint', 'mint', [
                types.uint(1),
                types.utf8("ipfs://token-metadata")
            ], wallet_1.address),
            
            Tx.contractCall('safe-mint', 'list-token', [
                types.uint(1),
                types.uint(1),
                types.uint(150000000)
            ], wallet_1.address)
        ]);
        
        // Buy token
        let buyBlock = chain.mineBlock([
            Tx.contractCall('safe-mint', 'buy-token', [
                types.uint(1),
                types.uint(1)
            ], wallet_2.address)
        ]);
        
        buyBlock.receipts[0].result.expectOk().expectBool(true);
        
        // Verify new owner
        let owner = chain.callReadOnlyFn(
            'safe-mint',
            'get-token-owner',
            [types.uint(1), types.uint(1)],
            wallet_1.address
        );
        
        assertEquals(owner.result.expectPrincipal(), wallet_2.address);
    }
});
