;; Consolidated implementation of the Decentralized Talent Protocol

;; =================== CORE FUNCTIONALITY ====================

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-unauthorized (err u102))
(define-constant err-already-exists (err u103))
(define-constant err-invalid-params (err u104))
(define-constant err-insufficient-funds (err u105))

;; ====== Protocol Fee Settings ======
(define-data-var minting-fee uint u1000000) ;; 1 STX
(define-data-var transaction-fee-percent uint u1) ;; 1%
(define-data-var dao-treasury uint u0)

;; DTP Protocol Version
(define-data-var protocol-version (string-ascii 10) "1.0.0")

;; ====== Fee Management ======

;; Update the minting fee
(define-public (update-minting-fee (new-fee uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (var-set minting-fee new-fee)
    (ok true)
  )
)

;; Update the transaction fee percentage
(define-public (update-transaction-fee (new-fee-percent uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (<= new-fee-percent u10) err-invalid-params) ;; Max 10%
    (var-set transaction-fee-percent new-fee-percent)
    (ok true)
  )
)

;; Get the current minting fee
(define-read-only (get-minting-fee)
  (var-get minting-fee)
)

;; Get the current transaction fee percentage
(define-read-only (get-transaction-fee-percent)
  (var-get transaction-fee-percent)
)

;; ====== Treasury Management ======

;; Collect fee
(define-public (collect-fee (amount uint))
  (begin
    ;; No need for module verification in consolidated contract
    (var-set dao-treasury (+ (var-get dao-treasury) amount))
    (ok true)
  )
)

;; Withdraw funds from treasury (requires governance approval)
(define-public (withdraw-treasury (amount uint) (recipient principal))
  (begin
    ;; Only contract owner can withdraw in this consolidated version
    ;; In a modular version, this would check for governance approval
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (<= amount (var-get dao-treasury)) err-invalid-params)
    
    ;; Update treasury balance
    (var-set dao-treasury (- (var-get dao-treasury) amount))
    
    ;; Transfer funds
    (try! (stx-transfer? amount contract-owner recipient))
    
    (ok true)
  )
)

;; Get treasury balance
(define-read-only (get-treasury-balance)
  (var-get dao-treasury)
)

;; ====== Protocol Version Management ======

;; Update the protocol version (owner only)
(define-public (update-protocol-version (new-version (string-ascii 10)))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (var-set protocol-version new-version)
    (ok true)
  )
)

;; Get the current protocol version
(define-read-only (get-protocol-version)
  (var-get protocol-version)
)