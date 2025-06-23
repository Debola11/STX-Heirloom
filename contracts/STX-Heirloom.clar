;; Intergenerational Wealth Trust
;; Enhanced version with comprehensive data validation

;; Error codes
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-ALREADY-INITIALIZED (err u101))
(define-constant ERR-NOT-ACTIVE (err u102))
(define-constant ERR-INVALID-AGE (err u103))
(define-constant ERR-MILESTONE-NOT-FOUND (err u104))
(define-constant ERR-MILESTONE-ALREADY-COMPLETED (err u105))
(define-constant ERR-INSUFFICIENT-BALANCE (err u106))
(define-constant ERR-INVALID-MILESTONE (err u107))
(define-constant ERR-INVALID-TIME (err u108))
(define-constant ERR-GUARDIAN-ALREADY-SET (err u109))
(define-constant ERR-NO-GUARDIAN (err u110))
(define-constant ERR-INVALID-AMOUNT (err u111))
(define-constant ERR-INVALID-BIRTH-HEIGHT (err u112))
(define-constant ERR-ZERO-ALLOCATION (err u113))
(define-constant ERR-INVALID-BONUS (err u114))
(define-constant ERR-INVALID-DEADLINE (err u115))
(define-constant ERR-INVALID-STATUS (err u116))
(define-constant ERR-SELF-GUARDIAN (err u117))
(define-constant ERR-TRANSFER-FAILED (err u118))

;; Constants for validation
(define-constant MINIMUM-AGE-REQUIREMENT u16)
(define-constant MAXIMUM-AGE-REQUIREMENT u100)
(define-constant MAXIMUM-BONUS_MULTIPLIER u500) ;; 5x maximum bonus
(define-constant MINIMUM_ALLOCATION u1000000) ;; 1 STX minimum allocation
(define-constant BLOCKS_PER_DAY u144)
(define-constant VALID-STATUS-VALUES (list "active" "paused" "completed"))

;; Data Variables
(define-data-var contract-owner principal tx-sender)
(define-data-var active bool true)
(define-data-var emergency-contact principal tx-sender)
(define-data-var minimum-vesting-period uint u52560) ;; ~1 year in blocks

;; Data Maps
(define-map heirs 
    principal 
    {
        birth-height: uint,
        total-allocation: uint,
        claimed-amount: uint,
        status: (string-ascii 9),
        guardian: (optional principal),
        vesting-start: uint,
        education-bonus: uint,
        last-activity: uint
    }
)

(define-map milestones
    uint
    {
        description: (string-ascii 100),
        reward-amount: uint,
        age-requirement: uint,
        completed: bool,
        deadline: (optional uint),
        bonus-multiplier: uint,
        requires-guardian: bool
    }
)

(define-map guardian-approvals
    { heir: principal, milestone-id: uint }
    { approved: bool, timestamp: uint }
)

;; Helper functions for validation
(define-private (validate-birth-height (birth-height uint))
    (and 
        (>= birth-height u0)
        (<= birth-height stacks-block-height))
)

(define-private (validate-allocation (amount uint))
    (and 
        (>= amount MINIMUM_ALLOCATION)
        (<= amount (stx-get-balance tx-sender)))
)

(define-private (validate-bonus-multiplier (multiplier uint))
    (and 
        (>= multiplier u100)
        (<= multiplier MAXIMUM-BONUS_MULTIPLIER))
)

(define-private (validate-age-requirement (age uint))
    (and 
        (>= age MINIMUM-AGE-REQUIREMENT)
        (<= age MAXIMUM-AGE-REQUIREMENT))
)

(define-private (validate-deadline (deadline-height (optional uint)))
    (match deadline-height
        height (> height stacks-block-height)
        true)
)

(define-private (validate-status (status (string-ascii 9))) ;; Updated parameter type
    (is-some (index-of VALID-STATUS-VALUES status))
)

;; Private utility functions
(define-private (is-contract-owner)
    (is-eq tx-sender (var-get contract-owner))
)

(define-private (is-active)
    (var-get active)
)

(define-private (is-guardian-or-owner (heir principal))
    (match (get-heir-info heir)
        heir-data (or 
            (is-contract-owner)
            (match (get guardian heir-data)
                guardian (is-eq tx-sender guardian)
                false
            ))
        false
    )
)

(define-private (safe-transfer (amount uint) (sender principal) (recipient principal))
    (match (as-contract (stx-transfer? amount sender recipient))
        success (ok true)
        error (err ERR-TRANSFER-FAILED))
)

;; Read-only functions
(define-read-only (get-heir-info (heir principal))
    (map-get? heirs heir)
)

(define-read-only (get-milestone (milestone-id uint))
    (map-get? milestones milestone-id)
)

(define-read-only (calculate-age (birth-height uint))
    (if (validate-birth-height birth-height)
        (if (>= stacks-block-height birth-height)
            (/ (- stacks-block-height birth-height) BLOCKS_PER_DAY)
            u0)
        u0)
)

(define-read-only (get-guardian-approval (heir principal) (milestone-id uint))
    (map-get? guardian-approvals { heir: heir, milestone-id: milestone-id })
)

(define-read-only (get-vesting-status (heir principal))
    (match (get-heir-info heir)
        heir-data (>= (- stacks-block-height (get vesting-start heir-data)) 
                     (var-get minimum-vesting-period))
        false
    )
)

(define-private (check-age-requirement (heir principal) (required-age uint))
    (match (get-heir-info heir)
        heir-data (>= (calculate-age (get birth-height heir-data)) required-age)
        false
    )
)


;; Update add-heir function
(define-public (add-heir (heir principal) 
                        (birth-height uint) 
                        (allocation uint)
                        (guardian (optional principal)))
    (begin
        (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)
        (asserts! (is-active) ERR-NOT-ACTIVE)
        (asserts! (is-none (get-heir-info heir)) ERR-ALREADY-INITIALIZED)
        (asserts! (validate-birth-height birth-height) ERR-INVALID-BIRTH-HEIGHT)
        (asserts! (validate-allocation allocation) ERR-ZERO-ALLOCATION)
        (asserts! (match guardian 
            g (not (is-eq g heir))
            true) 
            ERR-SELF-GUARDIAN)

        (map-set heirs heir {
            birth-height: birth-height,
            total-allocation: allocation,
            claimed-amount: u0,
            status: "active",  ;; This is now within 9 characters
            guardian: guardian,
            vesting-start: stacks-block-height,
            education-bonus: u0,
            last-activity: stacks-block-height
        })

        (ok true)
    )
)
