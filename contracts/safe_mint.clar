;; SafeMint - Secure NFT creation platform with secondary market support

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-already-exists (err u102))
(define-constant err-invalid-params (err u103))
(define-constant err-insufficient-funds (err u104))
(define-constant err-contract-paused (err u105))
(define-constant err-collection-paused (err u106))
(define-constant err-invalid-uri (err u107))

;; Data Variables
(define-data-var last-collection-id uint u0)
(define-data-var contract-paused bool false)

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
        floor-price: uint,
        paused: bool
    }
)

;; [Previous maps remain unchanged]

;; Events
(define-data-var last-event-id uint u0)
(define-map events 
    uint 
    {
        event-type: (string-ascii 24),
        collection-id: uint,
        token-id: uint,
        sender: principal,
        recipient: (optional principal),
        amount: (optional uint)
    }
)

;; Administrative Functions
(define-public (toggle-contract-pause)
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (ok (var-set contract-paused (not (var-get contract-paused))))
    )
)

(define-public (toggle-collection-pause (collection-id uint))
    (let ((collection (unwrap! (map-get? collections collection-id) err-not-found)))
        (asserts! (is-eq tx-sender (get creator collection)) err-owner-only)
        (map-set collections collection-id (merge collection { paused: (not (get paused collection)) }))
        (ok true)
    )
)

;; Event Management
(define-private (emit-event 
    (event-type (string-ascii 24))
    (collection-id uint)
    (token-id uint)
    (recipient (optional principal))
    (amount (optional uint)))
    (let ((new-event-id (+ (var-get last-event-id) u1)))
        (map-set events new-event-id {
            event-type: event-type,
            collection-id: collection-id,
            token-id: token-id,
            sender: tx-sender,
            recipient: recipient,
            amount: amount
        })
        (var-set last-event-id new-event-id)
        new-event-id
    )
)

;; Batch Minting
(define-public (batch-mint 
    (collection-id uint)
    (metadata-uris (list 25 (string-utf8 256))))
    (let ((collection (unwrap! (map-get? collections collection-id) err-not-found))
         (minted (default-to u0 (map-get? collection-minted collection-id))))
        
        (asserts! (not (var-get contract-paused)) err-contract-paused)
        (asserts! (not (get paused collection)) err-collection-paused)
        (asserts! (<= (+ minted (len metadata-uris)) (get max-supply collection)) err-invalid-params)
        
        (map mint-single (make-list (len metadata-uris) collection-id) metadata-uris)
        (ok true)
    )
)

(define-private (mint-single (collection-id uint) (metadata-uri (string-utf8 256)))
    (let ((minted (default-to u0 (map-get? collection-minted collection-id)))
         (new-token-id (+ minted u1)))
        
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
        (emit-event "mint" collection-id new-token-id none none)
        (ok { collection-id: collection-id, token-id: new-token-id })
    )
)

;; [Rest of the original contract functions remain unchanged but with added event emissions]

;; Additional Read-Only Functions
(define-read-only (get-total-minted (collection-id uint))
    (default-to u0 (map-get? collection-minted collection-id))
)

(define-read-only (get-event (event-id uint))
    (map-get? events event-id)
)
