;; SafeMint - Secure NFT creation platform

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-already-exists (err u102))
(define-constant err-invalid-params (err u103))

;; Data Variables
(define-data-var last-collection-id uint u0)

;; Data Maps
(define-map collections 
    uint 
    {
        name: (string-ascii 64),
        symbol: (string-ascii 10),
        metadata-uri: (string-utf8 256),
        royalty-percent: uint,
        max-supply: uint,
        creator: principal
    }
)

(define-map collection-tokens 
    { collection-id: uint, token-id: uint } 
    {
        owner: principal,
        metadata-uri: (string-utf8 256)
    }
)

(define-map collection-minted
    uint
    uint
)

;; SFTs for each collection
(define-non-fungible-token nft-token { collection-id: uint, token-id: uint })

;; Administrative Functions
(define-public (create-collection 
    (name (string-ascii 64))
    (symbol (string-ascii 10))
    (metadata-uri (string-utf8 256))
    (royalty-percent uint)
    (max-supply uint))
    (let
        ((new-collection-id (+ (var-get last-collection-id) u1)))
        (asserts! (<= royalty-percent u100) err-invalid-params)
        (asserts! (> max-supply u0) err-invalid-params)
        
        (try! (map-insert collections new-collection-id {
            name: name,
            symbol: symbol,
            metadata-uri: metadata-uri,
            royalty-percent: royalty-percent,
            max-supply: max-supply,
            creator: tx-sender
        }))
        
        (map-insert collection-minted new-collection-id u0)
        (var-set last-collection-id new-collection-id)
        (ok new-collection-id)
    )
)

;; Minting Functions
(define-public (mint 
    (collection-id uint)
    (metadata-uri (string-utf8 256)))
    (let 
        ((collection (unwrap! (map-get? collections collection-id) err-not-found))
         (minted (default-to u0 (map-get? collection-minted collection-id)))
         (new-token-id (+ minted u1)))
        
        (asserts! (<= new-token-id (get max-supply collection)) err-invalid-params)
        
        (try! (nft-mint? nft-token 
            { collection-id: collection-id, token-id: new-token-id }
            tx-sender))
            
        (map-set collection-tokens 
            { collection-id: collection-id, token-id: new-token-id }
            {
                owner: tx-sender,
                metadata-uri: metadata-uri
            })
            
        (map-set collection-minted collection-id new-token-id)
        (ok { collection-id: collection-id, token-id: new-token-id })
    )
)

;; Transfer Function
(define-public (transfer 
    (collection-id uint)
    (token-id uint)
    (recipient principal))
    (let
        ((token-data (unwrap! (map-get? collection-tokens { collection-id: collection-id, token-id: token-id }) err-not-found)))
        
        (asserts! (is-eq tx-sender (get owner token-data)) err-invalid-params)
        
        (try! (nft-transfer? nft-token
            { collection-id: collection-id, token-id: token-id }
            tx-sender
            recipient))
            
        (map-set collection-tokens
            { collection-id: collection-id, token-id: token-id }
            {
                owner: recipient,
                metadata-uri: (get metadata-uri token-data)
            })
        (ok true)
    )
)

;; Read Only Functions
(define-read-only (get-collection-info (collection-id uint))
    (map-get? collections collection-id)
)

(define-read-only (get-token-owner (collection-id uint) (token-id uint))
    (get owner (unwrap! (map-get? collection-tokens { collection-id: collection-id, token-id: token-id }) err-not-found))
)

(define-read-only (get-token-uri (collection-id uint) (token-id uint))
    (get metadata-uri (unwrap! (map-get? collection-tokens { collection-id: collection-id, token-id: token-id }) err-not-found))
)