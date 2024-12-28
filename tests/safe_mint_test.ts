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
                types.uint(1000) // max supply
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
    name: "Can mint NFT from collection",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const wallet_1 = accounts.get('wallet_1')!;
        
        // First create collection
        let block = chain.mineBlock([
            Tx.contractCall('safe-mint', 'create-collection', [
                types.ascii("Test Collection"),
                types.ascii("TEST"),
                types.utf8("ipfs://metadata"),
                types.uint(5),
                types.uint(1000)
            ], wallet_1.address)
        ]);
        
        // Then mint token
        let mintBlock = chain.mineBlock([
            Tx.contractCall('safe-mint', 'mint', [
                types.uint(1), // collection id
                types.utf8("ipfs://token-metadata")
            ], wallet_1.address)
        ]);
        
        mintBlock.receipts[0].result.expectOk();
        
        // Verify token owner
        let owner = chain.callReadOnlyFn(
            'safe-mint',
            'get-token-owner',
            [types.uint(1), types.uint(1)],
            wallet_1.address
        );
        
        assertEquals(owner.result.expectPrincipal(), wallet_1.address);
    }
});

Clarinet.test({
    name: "Can transfer NFT",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const wallet_1 = accounts.get('wallet_1')!;
        const wallet_2 = accounts.get('wallet_2')!;
        
        // Create collection and mint
        let block = chain.mineBlock([
            Tx.contractCall('safe-mint', 'create-collection', [
                types.ascii("Test Collection"),
                types.ascii("TEST"),
                types.utf8("ipfs://metadata"),
                types.uint(5),
                types.uint(1000)
            ], wallet_1.address),
            Tx.contractCall('safe-mint', 'mint', [
                types.uint(1),
                types.utf8("ipfs://token-metadata")
            ], wallet_1.address)
        ]);
        
        // Transfer token
        let transferBlock = chain.mineBlock([
            Tx.contractCall('safe-mint', 'transfer', [
                types.uint(1), // collection id
                types.uint(1), // token id
                types.principal(wallet_2.address)
            ], wallet_1.address)
        ]);
        
        transferBlock.receipts[0].result.expectOk().expectBool(true);
        
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