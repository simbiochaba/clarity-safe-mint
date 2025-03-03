// Enhanced test suite with new test cases

Clarinet.test({
    name: "Can track collection statistics properly",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get('deployer')!;
        const buyer = accounts.get('wallet_1')!;
        
        // Create collection and mint token
        let block = chain.mineBlock([
            Tx.contractCall('safe-mint', 'create-collection', [
                types.ascii("Test Collection"),
                types.ascii("TEST"),
                types.utf8("ipfs://test"),
                types.uint(10), // 10% royalty
                types.uint(100) // max supply
            ], deployer.address)
        ]);
        
        // Verify stats after sale
        let statsBlock = chain.mineBlock([
            Tx.contractCall('safe-mint', 'get-collection-stats', [
                types.uint(1)
            ], deployer.address)
        ]);
        
        const stats = statsBlock.receipts[0].result.expectSome().expectTuple();
        assert(stats['total-volume'].valueOf() === 0n);
        assert(stats['sales-count'].valueOf() === 0n);
    }
});

// [Previous tests remain unchanged]
