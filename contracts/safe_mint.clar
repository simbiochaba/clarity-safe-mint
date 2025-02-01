;; SafeMint - Secure NFT creation platform with secondary market support

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-already-exists (err u102))
(define-constant err-invalid-params (err u103))
(define-constant err-insufficient-funds (err u104))

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
        creator: principal,
        floor-price: uint
    }
)

(define-map collection-tokens 
    { collection-id: uint, token-id: uint } 
    {
        owner: principal,
        metadata-uri: (string-utf8 256),
        listed: bool,
        price: uint
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
    (max-supply uint)
    (floor-price uint))
    (let
        ((new-collection-id (+ (var-get last-collection-id) u1)))
        (asserts! (<= royalty-percent u100) err-invalid-params)
        (asserts! (> max-supply u0) err-invalid-params)
        (asserts! (> floor-price u0) err-invalid-params)
        
        (try! (map-insert collections new-collection-id {
            name: name,
            symbol: symbol,
            metadata-uri: metadata-uri,
            royalty-percent: royalty-percent,
            max-supply: max-supply,
            creator: tx-sender,
            floor-price: floor-price
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
                metadata-uri: metadata-uri,
                listed: false,
                price: u0
            })
            
        (map-set collection-minted collection-id new-token-id)
        (ok { collection-id: collection-id, token-id: new-token-id })
    )
)

;; Secondary Market Functions
(define-public (list-token
    (collection-id uint)
    (token-id uint)
    (price uint))
    (let
        ((token-data (unwrap! (map-get? collection-tokens { collection-id: collection-id, token-id: token-id }) err-not-found))
         (collection (unwrap! (map-get? collections collection-id) err-not-found)))
        
        (asserts! (is-eq tx-sender (get owner token-data)) err-invalid-params)
        (asserts! (>= price (get floor-price collection)) err-invalid-params)
        
        (map-set collection-tokens
            { collection-id: collection-id, token-id: token-id }
            {
                owner: (get owner token-data),
                metadata-uri: (get metadata-uri token-data),
                listed: true,
                price: price
            })
        (ok true)
    )
)

(define-public (unlist-token
    (collection-id uint)
    (token-id uint))
    (let
        ((token-data (unwrap! (map-get? collection-tokens { collection-id: collection-id, token-id: token-id }) err-not-found)))
        
        (asserts! (is-eq tx-sender (get owner token-data)) err-invalid-params)
        
        (map-set collection-tokens
            { collection-id: collection-id, token-id: token-id }
            {
                owner: (get owner token-data),
                metadata-uri: (get metadata-uri token-data),
                listed: false,
                price: u0
            })
        (ok true)
    )
)

(define-public (buy-token 
    (collection-id uint)
    (token-id uint))
    (let
        ((token-data (unwrap! (map-get? collection-tokens { collection-id: collection-id, token-id: token-id }) err-not-found))
         (collection (unwrap! (map-get? collections collection-id) err-not-found))
         (price (get price token-data))
         (seller (get owner token-data))
         (royalty-amount (/ (* price (get royalty-percent collection)) u100)))
        
        (asserts! (get listed token-data) err-invalid-params)
        
        ;; Transfer STX payment
        (try! (stx-transfer? price tx-sender seller))
        ;; Transfer royalty
        (try! (stx-transfer? royalty-amount tx-sender (get creator collection)))
        
        ;; Transfer NFT
        (try! (nft-transfer? nft-token
            { collection-id: collection-id, token-id: token-id }
            seller
            tx-sender))
            
        (map-set collection-tokens
            { collection-id: collection-id, token-id: token-id }
            {
                owner: tx-sender,
                metadata-uri: (get metadata-uri token-data),
                listed: false,
                price: u0
            })
        (ok true)
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
        (asserts! (not (get listed token-data)) err-invalid-params)
        
        (try! (nft-transfer? nft-token
            { collection-id: collection-id, token-id: token-id }
            tx-sender
            recipient))
            
        (map-set collection-tokens
            { collection-id: collection-id, token-id: token-id }
            {
                owner: recipient,
                metadata-uri: (get metadata-uri token-data),
                listed: false,
                price: u0
            })
        (ok true)
    )
)

;; Read Only Functions
(define-read-only (get-collection-info (collection-id uint))
    (map-get? collections collection-id)
)

(define-read-only (get-token-info (collection-id uint) (token-id uint))
    (map-get? collection-tokens { collection-id: collection-id, token-id: token-id })
)

(define-read-only (get-token-owner (collection-id uint) (token-id uint))
    (get owner (unwrap! (map-get? collection-tokens { collection-id: collection-id, token-id: token-id }) err-not-found))
)

(define-read-only (get-token-uri (collection-id uint) (token-id uint))
    (get metadata-uri (unwrap! (map-get? collection-tokens { collection-id: collection-id, token-id: token-id }) err-not-found))
)
