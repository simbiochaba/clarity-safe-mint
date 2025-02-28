// [Previous test content remains, adding new tests for new features]

Clarinet.test({
    name: "Can pause and unpause contract",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get('deployer')!;
        
        let block = chain.mineBlock([
            Tx.contractCall('safe-mint', 'toggle-contract-pause', [], deployer.address)
        ]);
        
        block.receipts[0].result.expectOk().expectBool(true);
        
        // Try to mint while paused
        let mintBlock = chain.mineBlock([
            Tx.contractCall('safe-mint', 'mint', [
                types.uint(1),
                types.utf8("ipfs://test")
            ], deployer.address)
        ]);
        
        mintBlock.receipts[0].result.expectErr().expectUint(105); // err-contract-paused
    }
});

// [Additional tests for batch minting and other new features]
