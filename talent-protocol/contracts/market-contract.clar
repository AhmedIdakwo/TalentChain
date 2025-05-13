;; DTP-Consolidated.clar
;; Consolidated implementation of the Decentralized Talent Protocol

;; ============================================================
;; =================== CORE FUNCTIONALITY ====================
;; ============================================================

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

;; ===================== PROFILE MODULE ======================

;; Profile NFT counter
(define-data-var next-profile-id uint u0)

;; User profiles
(define-map user-profiles
  { user: principal }
  {
    did: (optional (string-utf8 256)),
    reputation-score: uint,
    registration-time: uint,
    career-token-id: (optional (string-utf8 36)),
    description: (optional (string-utf8 500))
  }
)

;; Register a new profile
(define-public (register-profile 
  (did (optional (string-utf8 256)))
  (description (optional (string-utf8 500)))
)
  (let ((user tx-sender)
        (profile-id (concat "profile-" (to-string (var-get next-profile-id))))
        (current-time (get-block-info? time (- block-height u1))))
    
    ;; Check if profile already exists
    (asserts! (is-none (map-get? user-profiles { user: user })) err-already-exists)
    
    ;; Get the minting fee
    (let ((minting-fee (var-get minting-fee)))
      
      ;; Charge minting fee
      (try! (stx-transfer? minting-fee tx-sender contract-owner))
      
      ;; Send fee to treasury
      (try! (collect-fee minting-fee))
      
      ;; Create the profile
      (map-set user-profiles
        { user: user }
        {
          did: did,
          reputation-score: u1,
          registration-time: (default-to u0 current-time),
          career-token-id: none,
          description: description
        }
      )
      
      ;; Increment the profile counter
      (var-set next-profile-id (+ (var-get next-profile-id) u1))
      
      ;; Return the new profile ID
      (ok profile-id)
    )
  )
)

;; Get a user's profile
(define-read-only (get-profile (user principal))
  (let ((profile-data (map-get? user-profiles { user: user })))
    (if (is-some profile-data)
      (ok (unwrap-panic profile-data))
      err-not-found
    )
  )
)

;; Update a user's reputation score (internal function, called from other functions)
(define-private (update-reputation-internal (user principal) (score-change uint))
  (let ((profile-data (map-get? user-profiles { user: user })))
    (if (is-some profile-data)
      (let ((current-profile (unwrap-panic profile-data))
            (new-score (+ (get reputation-score current-profile) score-change)))
        (map-set user-profiles
          { user: user }
          (merge current-profile { reputation-score: new-score })
        )
        true
      )
      false
    )
  )
)

;; Public function to update reputation (restricted)
(define-public (update-reputation (user principal) (score-change uint))
  (begin
    ;; Only contract owner can update reputation in this consolidated version
    ;; In a modular version, this would be called by authorized modules
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (if (update-reputation-internal user score-change)
      (ok true)
      err-not-found
    )
  )
)

;; Update profile description
(define-public (update-profile-description (description (string-utf8 500)))
  (let ((user tx-sender)
        (profile-data (map-get? user-profiles { user: user })))
    (if (is-some profile-data)
      (begin
        (map-set user-profiles
          { user: user }
          (merge (unwrap-panic profile-data) { description: (some description) })
        )
        (ok true)
      )
      err-not-found
    )
  )
)

;; ============================================================
;; ===================== SKILLS MODULE =======================
;; ============================================================

;; NFT counter
(define-data-var next-skill-id uint u0)

;; Skill NFTs owned by users
(define-map skill-nfts
  { skill-id: (string-utf8 36) }
  {
    owner: principal,
    name: (string-utf8 100),
    description: (string-utf8 500),
    issuer: principal,
    issue-date: uint,
    verification-proof: (string-utf8 256), ;; Could be a hash of off-chain proof
    metadata-uri: (string-utf8 256)
  }
)

;; NFT ownership index
(define-map user-skills
  { user: principal, skill-id: (string-utf8 36) }
  { owned: bool }
)

;; Mint a new skill NFT
(define-public (mint-skill-nft 
  (name (string-utf8 100)) 
  (description (string-utf8 500))
  (verification-proof (string-utf8 256))
  (metadata-uri (string-utf8 256))
)
  (let ((user tx-sender)
        (skill-id (concat "skill-" (to-string (var-get next-skill-id))))
        (current-time (get-block-info? time (- block-height u1))))
    
    ;; Get the minting fee
    (let ((minting-fee (var-get minting-fee)))
      
      ;; Charge minting fee
      (try! (stx-transfer? minting-fee tx-sender contract-owner))
      
      ;; Send fee to treasury
      (try! (collect-fee minting-fee))
      
      ;; Create the NFT
      (map-set skill-nfts
        { skill-id: skill-id }
        {
          owner: user,
          name: name,
          description: description,
          issuer: user,
          issue-date: (default-to u0 current-time),
          verification-proof: verification-proof,
          metadata-uri: metadata-uri
        }
      )
      
      ;; Update the ownership index
      (map-set user-skills
        { user: user, skill-id: skill-id }
        { owned: true }
      )
      
      ;; Increment the skill NFT counter
      (var-set next-skill-id (+ (var-get next-skill-id) u1))
      
      ;; Return the new skill ID
      (ok skill-id)
    )
  )
)

;; Issue a skill NFT to another user (for organizations issuing certifications)
(define-public (issue-skill-nft 
  (recipient principal)
  (name (string-utf8 100)) 
  (description (string-utf8 500))
  (verification-proof (string-utf8 256))
  (metadata-uri (string-utf8 256))
)
  (let ((issuer tx-sender)
        (skill-id (concat "skill-" (to-string (var-get next-skill-id))))
        (current-time (get-block-info? time (- block-height u1))))
    
    ;; Get the minting fee
    (let ((minting-fee (var-get minting-fee)))
      
      ;; Charge minting fee
      (try! (stx-transfer? minting-fee tx-sender contract-owner))
      
      ;; Send fee to treasury
      (try! (collect-fee minting-fee))
      
      ;; Create the NFT
      (map-set skill-nfts
        { skill-id: skill-id }
        {
          owner: recipient,
          name: name,
          description: description,
          issuer: issuer,
          issue-date: (default-to u0 current-time),
          verification-proof: verification-proof,
          metadata-uri: metadata-uri
        }
      )
      
      ;; Update the ownership index
      (map-set user-skills
        { user: recipient, skill-id: skill-id }
        { owned: true }
      )
      
      ;; Increment the skill NFT counter
      (var-set next-skill-id (+ (var-get next-skill-id) u1))
      
      ;; Return the new skill ID
      (ok skill-id)
    )
  )
)

;; Get skill NFT details
(define-read-only (get-skill-nft (skill-id (string-utf8 36)))
  (let ((skill-data (map-get? skill-nfts { skill-id: skill-id })))
    (if (is-some skill-data)
      (ok (unwrap-panic skill-data))
      err-not-found
    )
  )
)

;; Get all skill NFTs owned by a user
(define-read-only (get-user-skills (user principal))
  (ok (filter owned-by-user (map-keys skill-nfts)))
  
  ;; Helper function to check if a skill is owned by the user
  (define-private (owned-by-user (skill-key { skill-id: (string-utf8 36) }))
    (let ((skill-data (unwrap! (map-get? skill-nfts skill-key) false)))
      (is-eq (get owner skill-data) user)
    )
  )
)

;; Transfer a skill NFT to another user
(define-public (transfer-skill (skill-id (string-utf8 36)) (recipient principal))
  (let ((sender tx-sender)
        (skill-data (unwrap! (map-get? skill-nfts { skill-id: skill-id }) err-not-found)))
    
    ;; Ensure sender is the owner
    (asserts! (is-eq (get owner skill-data) sender) err-unauthorized)
    
    ;; Update ownership
    (map-set skill-nfts
      { skill-id: skill-id }
      (merge skill-data { owner: recipient })
    )
    
    ;; Update the ownership index for the sender
    (map-set user-skills
      { user: sender, skill-id: skill-id }
      { owned: false }
    )
    
    ;; Update the ownership index for the recipient
    (map-set user-skills
      { user: recipient, skill-id: skill-id }
      { owned: true }
    )
    
    (ok true)
  )
)

;; Verify a user has a specific skill
(define-public (verify-skill (user principal) (skill-id (string-utf8 36)))
  (let ((skill-data (unwrap! (map-get? skill-nfts { skill-id: skill-id }) err-not-found)))
    (ok (is-eq (get owner skill-data) user))
  )
)

;; Check if a user has any skills with a specific issuer
(define-read-only (has-skills-from-issuer (user principal) (issuer principal))
  (let ((user-skill-list (unwrap! (get-user-skills user) false)))
    (ok (is-some (find has-issuer user-skill-list)))
    
    ;; Helper to check if a skill has the specified issuer
    (define-private (has-issuer (skill-key { skill-id: (string-utf8 36) }))
      (let ((skill-data (unwrap! (map-get? skill-nfts skill-key) false)))
        (is-eq (get issuer skill-data) issuer)
      )
    )
  )
)

;; ============================================================
;; ===================== TOKEN MODULE ========================
;; ============================================================

;; Career Token counter
(define-data-var next-token-id uint u0)

;; Career Tokens
(define-map career-tokens
  { token-id: (string-utf8 36) }
  {
    creator: principal,
    name: (string-utf8 100),
    total-supply: uint,
    available-supply: uint,
    price: uint,
    description: (string-utf8 500),
    metadata-uri: (string-utf8 500),
    creation-time: uint
  }
)

;; Token balances
(define-map token-balances
  { token-id: (string-utf8 36), owner: principal }
  { balance: uint }
)

;; Create a new career token
(define-public (create-career-token
  (name (string-utf8 100))
  (total-supply uint)
  (price uint)
  (description (string-utf8 500))
  (metadata-uri (string-utf8 500))
)
  (let ((creator tx-sender)
        (token-id (concat "token-" (to-string (var-get next-token-id))))
        (current-time (get-block-info? time (- block-height u1))))
    
    ;; Get the minting fee
    (let ((minting-fee (var-get minting-fee)))
      
      ;; Charge minting fee
      (try! (stx-transfer? minting-fee tx-sender contract-owner))
      
      ;; Send fee to treasury
      (try! (collect-fee minting-fee))
      
      ;; Create the token
      (map-set career-tokens
        { token-id: token-id }
        {
          creator: creator,
          name: name,
          total-supply: total-supply,
          available-supply: total-supply,
          price: price,
          description: description,
          metadata-uri: metadata-uri,
          creation-time: (default-to u0 current-time)
        }
      )
      
      ;; Set initial balance for creator
      (map-set token-balances
        { token-id: token-id, owner: creator }
        { balance: u0 }
      )
      
      ;; Connect the token to the creator's profile
      (let ((profile-data (map-get? user-profiles { user: creator })))
        (if (is-some profile-data)
          (map-set user-profiles
            { user: creator }
            (merge (unwrap-panic profile-data) { career-token-id: (some token-id) })
          )
          true
        )
      )
      
      ;; Increment the token counter
      (var-set next-token-id (+ (var-get next-token-id) u1))
      
      ;; Return the new token ID
      (ok token-id)
    )
  )
)

;; Buy career tokens
(define-public (buy-career-tokens
  (token-id (string-utf8 36))
  (amount uint)
)
  (let ((buyer tx-sender)
        (token-data (unwrap! (map-get? career-tokens { token-id: token-id }) err-not-found)))
    
    ;; Check available supply
    (asserts! (>= (get available-supply token-data) amount) err-insufficient-funds)
    
    ;; Calculate cost with fees
    (let ((base-cost (* (get price token-data) amount))
          (fee (* base-cost (/ (var-get transaction-fee-percent) u100)))
          (total-cost (+ base-cost fee))
          (seller (get creator token-data)))
      
      ;; Transfer funds from buyer to seller
      (try! (stx-transfer? base-cost buyer seller))
      
      ;; Transfer fee to contract
      (try! (stx-transfer? fee buyer contract-owner))
      
      ;; Send fee to treasury
      (try! (collect-fee fee))
      
      ;; Update available supply
      (map-set career-tokens
        { token-id: token-id }
        (merge token-data { available-supply: (- (get available-supply token-data) amount) })
      )
      
      ;; Update buyer's balance
      (let ((current-balance (get-token-balance-internal token-id buyer)))
        (map-set token-balances
          { token-id: token-id, owner: buyer }
          { balance: (+ current-balance amount) }
        )
      )
      
      ;; Increase seller's reputation
      (update-reputation-internal seller u1)
      
      (ok true)
    )
  )
)
