;; Adaptive Ad Network Smart Contract
;; A decentralized advertising network with dynamic pricing and performance tracking

;; --- Constants and Errors ---
(define-constant contract-owner tx-sender) ;; The principal who deployed the contract (admin)
(define-constant err-owner-only (err u100)) ;; Sender must be the contract owner
(define-constant err-not-found (err u101)) ;; ID or principal not found in map
(define-constant err-already-exists (err u102)) ;; Principal or ID already registered
(define-constant err-insufficient-funds (err u103)) ;; Budget exhausted or not enough STX
(define-constant err-unauthorized (err u104)) ;; Sender is not the owner of the entity
(define-constant err-invalid-params (err u105)) ;; Invalid input parameters

;; --- Data Variables (State) ---
(define-data-var platform-fee-percentage uint u5) ;; 5% platform fee (Max 20%)
(define-data-var min-bid-amount uint u1000000) ;; Minimum allowable bid in microSTX

;; --- Data Maps ---
;; Map for storing advertiser details
(define-map advertisers
    principal
    {
        total-spent: uint,
        active-campaigns: uint,
        reputation-score: uint
    }
)

;; Map for storing campaign details
(define-map campaigns
    uint
    {
        advertiser: principal,
        name: (string-ascii 50),
        budget: uint,
        spent: uint,
        bid-amount: uint, ;; Default bid for this campaign
        impressions: uint,
        clicks: uint,
        conversions: uint,
        active: bool,
        created-at: uint
    }
)

;; Map for storing publisher details
(define-map publishers
    principal
    {
        total-earned: uint,
        active-slots: uint,
        reputation-score: uint
    }
)

;; Map for storing ad slot details
(define-map ad-slots
    uint
    {
        publisher: principal,
        name: (string-ascii 50),
        min-bid: uint, ;; Minimum required bid for this slot
        impressions: uint,
        clicks: uint,
        active: bool,
        created-at: uint
    }
)

;; Map for storing active bids between a campaign and a slot
(define-map campaign-slot-bids
    {campaign-id: uint, slot-id: uint}
    {
        bid-amount: uint,
        active: bool
    }
)

;; --- Counters ---
(define-data-var campaign-counter uint u0) ;; Used to generate sequential campaign IDs
(define-data-var slot-counter uint u0) ;; Used to generate sequential ad slot IDs

;; --- Private Functions ---
;; Calculates the platform fee based on the percentage stored in platform-fee-percentage
(define-private (calculate-platform-fee (amount uint))
    (/ (* amount (var-get platform-fee-percentage)) u100)
)

;; --- Public Functions - Advertiser Operations ---

;; Registers the caller as a new advertiser
(define-public (register-advertiser)
    (let ((advertiser tx-sender))
        (asserts! (is-none (map-get? advertisers advertiser)) err-already-exists)
        (ok (map-set advertisers advertiser {
            total-spent: u0,
            active-campaigns: u0,
            reputation-score: u100 ;; Initial score
        }))
    )
)

;; Creates a new campaign, transfers budget, and activates it
(define-public (create-campaign (name (string-ascii 50)) (budget uint) (bid-amount uint))
    (let (
        (advertiser tx-sender)
        (campaign-id (+ (var-get campaign-counter) u1))
        (advertiser-data (unwrap! (map-get? advertisers advertiser) err-not-found))
    )
        (asserts! (>= bid-amount (var-get min-bid-amount)) err-invalid-params)
        (asserts! (> budget u0) err-invalid-params)
        
        ;; Transfer budget from advertiser to the contract's principal (as-contract)
        (try! (stx-transfer? budget tx-sender (as-contract tx-sender)))
        
        ;; Store new campaign data
        (map-set campaigns campaign-id {
            advertiser: advertiser,
            name: name,
            budget: budget,
            spent: u0,
            bid-amount: bid-amount,
            impressions: u0,
            clicks: u0,
            conversions: u0,
            active: true,
            created-at: block-height
        })
        
        ;; Update advertiser's active campaign count
        (map-set advertisers advertiser (merge advertiser-data {
            active-campaigns: (+ (get active-campaigns advertiser-data) u1)
        }))
        
        (var-set campaign-counter campaign-id)
        (ok campaign-id)
    )
)

;; Allows the campaign owner to update the default bid amount
(define-public (update-campaign-bid (campaign-id uint) (new-bid-amount uint))
    (let (
        (campaign (unwrap! (map-get? campaigns campaign-id) err-not-found))
    )
        (asserts! (is-eq tx-sender (get advertiser campaign)) err-unauthorized) ;; Only owner can update
        (asserts! (>= new-bid-amount (var-get min-bid-amount)) err-invalid-params)
        
        (ok (map-set campaigns campaign-id (merge campaign {
            bid-amount: new-bid-amount
        })))
    )
)

;; Pauses an active campaign
(define-public (pause-campaign (campaign-id uint))
    (let (
        (campaign (unwrap! (map-get? campaigns campaign-id) err-not-found))
    )
        (asserts! (is-eq tx-sender (get advertiser campaign)) err-unauthorized)
        (ok (map-set campaigns campaign-id (merge campaign {active: false})))
    )
)

;; Resumes a paused campaign if it still has budget
(define-public (resume-campaign (campaign-id uint))
    (let (
        (campaign (unwrap! (map-get? campaigns campaign-id) err-not-found))
    )
        (asserts! (is-eq tx-sender (get advertiser campaign)) err-unauthorized)
        ;; Check if remaining budget is greater than zero
        (asserts! (< (get spent campaign) (get budget campaign)) err-insufficient-funds)
        (ok (map-set campaigns campaign-id (merge campaign {active: true})))
    )
)

;; --- Public Functions - Publisher Operations ---

;; Registers the caller as a new publisher
(define-public (register-publisher)
    (let ((publisher tx-sender))
        (asserts! (is-none (map-get? publishers publisher)) err-already-exists)
        (ok (map-set publishers publisher {
            total-earned: u0,
            active-slots: u0,
            reputation-score: u100
        }))
    )
)

;; Creates a new ad slot
(define-public (create-ad-slot (name (string-ascii 50)) (min-bid uint))
    (let (
        (publisher tx-sender)
        (slot-id (+ (var-get slot-counter) u1))
        (publisher-data (unwrap! (map-get? publishers publisher) err-not-found))
    )
        (asserts! (>= min-bid (var-get min-bid-amount)) err-invalid-params)
        
        ;; Store new ad slot data
        (map-set ad-slots slot-id {
            publisher: publisher,
            name: name,
            min-bid: min-bid,
            impressions: u0,
            clicks: u0,
            active: true,
            created-at: block-height
        })
        
        ;; Update publisher's active slot count
        (map-set publishers publisher (merge publisher-data {
            active-slots: (+ (get active-slots publisher-data) u1)
        }))
        
        (var-set slot-counter slot-id)
        (ok slot-id)
    )
)

;; Records an impression event (view) for a campaign in a slot. Called by the slot owner (publisher).
(define-public (record-impression (campaign-id uint) (slot-id uint))
    (let (
        (campaign (unwrap! (map-get? campaigns campaign-id) err-not-found))
        (slot (unwrap! (map-get? ad-slots slot-id) err-not-found))
        (bid (unwrap! (map-get? campaign-slot-bids {campaign-id: campaign-id, slot-id: slot-id}) err-not-found))
    )
        (asserts! (is-eq tx-sender (get publisher slot)) err-unauthorized) ;; Only slot publisher can record
        (asserts! (get active campaign) err-invalid-params) ;; Campaign must be active
        (asserts! (get active bid) err-invalid-params) ;; Bid must be active
        
        ;; Increment campaign impression counter
        (map-set campaigns campaign-id (merge campaign {
            impressions: (+ (get impressions campaign) u1)
        }))
        
        ;; Increment slot impression counter
        (ok (map-set ad-slots slot-id (merge slot {
            impressions: (+ (get impressions slot) u1)
        })))
    )
)

;; Allows a campaign to place its default bid on a specific slot
(define-public (place-bid (campaign-id uint) (slot-id uint))
    (let (
        (campaign (unwrap! (map-get? campaigns campaign-id) err-not-found))
        (slot (unwrap! (map-get? ad-slots slot-id) err-not-found))
        (bid-amount (get bid-amount campaign)) ;; Use campaign's default bid
    )
        (asserts! (is-eq tx-sender (get advertiser campaign)) err-unauthorized) ;; Only advertiser can bid
        (asserts! (>= bid-amount (get min-bid slot)) err-invalid-params) ;; Bid must meet slot minimum
        (asserts! (get active campaign) err-invalid-params)
        (asserts! (get active slot) err-invalid-params)
        
        ;; Record the active bid
        (ok (map-set campaign-slot-bids {campaign-id: campaign-id, slot-id: slot-id} {
            bid-amount: bid-amount,
            active: true
        }))
    )
)

;; --- Admin Functions ---

;; Allows the contract owner to change the platform fee percentage
(define-public (set-platform-fee (new-fee uint))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (asserts! (<= new-fee u20) err-invalid-params) ;; Enforce a maximum fee of 20%
        (ok (var-set platform-fee-percentage new-fee))
    )
)

;; Allows the contract owner to change the minimum required bid amount
(define-public (set-min-bid (new-min-bid uint))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (ok (var-set min-bid-amount new-min-bid))
    )
)

;; --- Read-only Functions ---
(define-read-only (get-campaign (campaign-id uint))
    (map-get? campaigns campaign-id)
)

(define-read-only (get-ad-slot (slot-id uint))
    (map-get? ad-slots slot-id)
)

(define-read-only (get-advertiser (advertiser principal))
    (map-get? advertisers advertiser)
)

(define-read-only (get-publisher (publisher principal))
    (map-get? publishers publisher)
)

(define-read-only (get-bid (campaign-id uint) (slot-id uint))
    (map-get? campaign-slot-bids {campaign-id: campaign-id, slot-id: slot-id})
)

(define-read-only (get-platform-fee)
    (var-get platform-fee-percentage)
)

(define-read-only (get-min-bid-amount)
    (var-get min-bid-amount)
)

;; Calculates and returns key performance indicators (KPIs) for a campaign, including CTR.
(define-read-only (get-campaign-performance (campaign-id uint))
    (match (map-get? campaigns campaign-id)
        campaign (ok {
            impressions: (get impressions campaign),
            clicks: (get clicks campaign),
            conversions: (get conversions campaign),
            spent: (get spent campaign),
            budget: (get budget campaign),
            ;; Calculate Click-Through Rate (CTR) using fixed-point arithmetic for precision.
            ;; CTR = (clicks / impressions) * 10000. 
            ;; The result should be interpreted as basis points (e.g., 500 means 5.00%).
            ctr: (if (> (get impressions campaign) u0)
                    (/ (* (get clicks campaign) u10000) (get impressions campaign))
                    u0)
        })
        err-not-found
    )
)

;; --- Newly-Added Feature:---
;; Records a click event, handles payment and budget deduction. Called by the slot owner (publisher).
(define-public (record-click (campaign-id uint) (slot-id uint))
    (let (
        (campaign (unwrap! (map-get? campaigns campaign-id) err-not-found))
        (slot (unwrap! (map-get? ad-slots slot-id) err-not-found))
        (bid (unwrap! (map-get? campaign-slot-bids {campaign-id: campaign-id, slot-id: slot-id}) err-not-found))
        (bid-amount (get bid-amount bid))
        (platform-fee (calculate-platform-fee bid-amount))
        (publisher-payment (- bid-amount platform-fee))
        (publisher (get publisher slot))
        (advertiser (get advertiser campaign))
        (publisher-data (unwrap! (map-get? publishers publisher) err-not-found))
        (advertiser-data (unwrap! (map-get? advertisers advertiser) err-not-found))
    )
        (asserts! (is-eq tx-sender publisher) err-unauthorized)
        (asserts! (get active campaign) err-invalid-params)
        (asserts! (get active bid) err-invalid-params)
        ;; Check if campaign has enough budget remaining for the bid amount
        (asserts! (<= (+ (get spent campaign) bid-amount) (get budget campaign)) err-insufficient-funds)
        
        ;; Payment: Transfer STX from the contract (tx-sender) to the publisher
        (try! (as-contract (stx-transfer? publisher-payment tx-sender publisher)))
        
        ;; Update campaign: increment clicks and spent budget
        (map-set campaigns campaign-id (merge campaign {
            clicks: (+ (get clicks campaign) u1),
            spent: (+ (get spent campaign) bid-amount)
        }))
        
        ;; Update slot: increment clicks
        (map-set ad-slots slot-id (merge slot {
            clicks: (+ (get clicks slot) u1)
        }))
        
        ;; Update publisher earnings (net payment)
        (map-set publishers publisher (merge publisher-data {
            total-earned: (+ (get total-earned publisher-data) publisher-payment)
        }))
        
        ;; Update advertiser total spending (gross bid)
        (map-set advertisers advertiser (merge advertiser-data {
            total-spent: (+ (get total-spent advertiser-data) bid-amount)
        }))
        
        ;; Pause campaign immediately if budget is exhausted or close to exhaustion after this click
        (if (<= (get budget campaign) (+ (get spent campaign) bid-amount))
            (map-set campaigns campaign-id (merge campaign {active: false}))
            true
        )
        
        (ok true)
    )
)


