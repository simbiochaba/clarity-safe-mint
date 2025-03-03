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

;; Event Types
(define-constant EVENT-MINT "mint")
(define-constant EVENT-TRANSFER "transfer")
(define-constant EVENT-LIST "list")
(define-constant EVENT-UNLIST "unlist")
(define-constant EVENT-SALE "sale")

;; Data Variables
(define-data-var last-collection-id uint u0)
(define-data-var contract-paused bool false)

;; Enhanced Collection Statistics
(define-map collection-stats
    uint 
    {
        total-volume: uint,
        sales-count: uint,
        last-sale-price: uint,
        highest-sale: uint
    }
)

;; Collections Map (unchanged)
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

;; Enhanced Events
(define-data-var last-event-id uint u0)
(define-map events 
    uint 
    {
        event-type: (string-ascii 24),
        collection-id: uint,
        token-id: uint,
        sender: principal,
        recipient: (optional principal),
        amount: (optional uint),
        tx-hash: (optional (buff 32))
    }
)

;; Collection Statistics Functions
(define-public (update-collection-stats 
    (collection-id uint)
    (sale-price uint))
    (let (
        (stats (default-to 
            { total-volume: u0, sales-count: u0, last-sale-price: u0, highest-sale: u0 }
            (map-get? collection-stats collection-id)))
        (new-volume (+ (get total-volume stats) sale-price))
        (new-count (+ (get sales-count stats) u1))
        (new-highest (if (> sale-price (get highest-sale stats))
            sale-price
            (get highest-sale stats)))
    )
    (map-set collection-stats collection-id
        {
            total-volume: new-volume,
            sales-count: new-count,
            last-sale-price: sale-price,
            highest-sale: new-highest
        }
    )
    (ok true))
)

;; Enhanced Event Emission
(define-private (emit-event 
    (event-type (string-ascii 24))
    (collection-id uint)
    (token-id uint)
    (recipient (optional principal))
    (amount (optional uint)))
    (let (
        (new-event-id (+ (var-get last-event-id) u1))
        (tx-hash (unwrap-panic (get-tx-hash)))
    )
        (map-set events new-event-id {
            event-type: event-type,
            collection-id: collection-id,
            token-id: token-id,
            sender: tx-sender,
            recipient: recipient,
            amount: amount,
            tx-hash: (some tx-hash)
        })
        (var-set last-event-id new-event-id)
        new-event-id
    )
)

;; Batch Transfer Function
(define-public (batch-transfer
    (collection-id uint)
    (token-ids (list 25 uint))
    (recipient principal))
    (let ((collection (unwrap! (map-get? collections collection-id) err-not-found)))
        (asserts! (not (var-get contract-paused)) err-contract-paused)
        (asserts! (not (get paused collection)) err-collection-paused)
        (map transfer-single (make-list (len token-ids) collection-id) token-ids (make-list (len token-ids) recipient))
        (ok true)
    )
)

(define-private (transfer-single (collection-id uint) (token-id uint) (recipient principal))
    (let ((token (unwrap! (map-get? collection-tokens { collection-id: collection-id, token-id: token-id }) err-not-found)))
        (asserts! (is-eq tx-sender (get owner token)) err-owner-only)
        (asserts! (not (get listed token)) err-invalid-params)
        
        (try! (nft-transfer? nft-token 
            { collection-id: collection-id, token-id: token-id }
            tx-sender
            recipient))
        
        (map-set collection-tokens 
            { collection-id: collection-id, token-id: token-id }
            (merge token { owner: recipient }))
        
        (emit-event EVENT-TRANSFER collection-id token-id (some recipient) none)
        (ok true)
    )
)

;; Read-Only Functions for Statistics
(define-read-only (get-collection-stats (collection-id uint))
    (map-get? collection-stats collection-id)
)

;; [Previous functions remain unchanged]
