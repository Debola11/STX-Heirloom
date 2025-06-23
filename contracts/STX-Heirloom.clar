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


(define-public (update-guardian (heir principal) (new-guardian principal))
    (let (
        (heir-data (unwrap! (get-heir-info heir) ERR-NOT-AUTHORIZED))
    )
    (begin
        (asserts! (is-guardian-or-owner heir) ERR-NOT-AUTHORIZED)
        (asserts! (not (is-eq new-guardian heir)) ERR-SELF-GUARDIAN)
        (map-set heirs heir (merge heir-data { 
            guardian: (some new-guardian),
            last-activity: stacks-block-height 
        }))
        (ok true)
    ))
)

(define-public (add-education-bonus (heir principal) (bonus-amount uint))
    (let (
        (heir-data (unwrap! (get-heir-info heir) ERR-NOT-AUTHORIZED))
    )
    (begin
        (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)
        (asserts! (> bonus-amount u0) ERR-INVALID-AMOUNT)

        (map-set heirs heir (merge heir-data { 
            education-bonus: (+ (get education-bonus heir-data) bonus-amount),
            last-activity: stacks-block-height
        }))
        (ok true)
    ))
)

(define-public (add-milestone (milestone-id uint) 
                            (description (string-ascii 100))
                            (reward-amount uint)
                            (age-requirement uint)
                            (deadline (optional uint))
                            (bonus-multiplier uint)
                            (requires-guardian bool))
    (begin
        (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)
        (asserts! (is-active) ERR-NOT-ACTIVE)
        (asserts! (is-none (get-milestone milestone-id)) ERR-ALREADY-INITIALIZED)
        (asserts! (validate-age-requirement age-requirement) ERR-INVALID-AGE)
        (asserts! (validate-bonus-multiplier bonus-multiplier) ERR-INVALID-BONUS)
        (asserts! (validate-deadline deadline) ERR-INVALID-DEADLINE)
        (asserts! (> reward-amount u0) ERR-INVALID-AMOUNT)

        (map-set milestones milestone-id {
            description: description,
            reward-amount: reward-amount,
            age-requirement: age-requirement,
            completed: false,
            deadline: deadline,
            bonus-multiplier: bonus-multiplier,
            requires-guardian: requires-guardian
        })

        (ok true)
    )
)

(define-public (approve-milestone (heir principal) (milestone-id uint))
    (let (
        (heir-data (unwrap! (get-heir-info heir) ERR-NOT-AUTHORIZED))
        (milestone (unwrap! (get-milestone milestone-id) ERR-MILESTONE-NOT-FOUND))
    )
    (begin
        (asserts! (is-guardian-or-owner heir) ERR-NOT-AUTHORIZED)
        (asserts! (get requires-guardian milestone) ERR-NOT-AUTHORIZED)

        (map-set guardian-approvals 
            { heir: heir, milestone-id: milestone-id }
            { approved: true, timestamp: stacks-block-height })
        (ok true)
    ))
)

;; Update claim-milestone function status check
(define-public (claim-milestone (heir principal) (milestone-id uint))
    (let (
        (heir-data (unwrap! (get-heir-info heir) ERR-NOT-AUTHORIZED))
        (milestone (unwrap! (get-milestone milestone-id) ERR-MILESTONE-NOT-FOUND))
    )
    (begin
        (asserts! (is-active) ERR-NOT-ACTIVE)
        (asserts! (is-eq tx-sender heir) ERR-NOT-AUTHORIZED)
        (asserts! (not (get completed milestone)) ERR-MILESTONE-ALREADY-COMPLETED)
        (asserts! (validate-status (get status heir-data)) ERR-INVALID-STATUS)
        (asserts! (is-eq (get status heir-data) "active") ERR-NOT-ACTIVE)
        (asserts! (check-age-requirement heir (get age-requirement milestone)) ERR-INVALID-AGE)
        (asserts! (get-vesting-status heir) ERR-INVALID-TIME)

        ;; Check guardian approval if required
        (asserts! (if (get requires-guardian milestone)
            (match (get-guardian-approval heir milestone-id)
                approval (get approved approval)
                false)
            true)
            ERR-NOT-AUTHORIZED)

        ;; Check deadline if exists
        (asserts! (validate-deadline (get deadline milestone)) ERR-INVALID-DEADLINE)

        ;; Calculate final reward with bonus
        (let (
            (base-reward (get reward-amount milestone))
            (bonus-reward (/ (* base-reward (- (get bonus-multiplier milestone) u100)) u100))
            (education-bonus (get education-bonus heir-data))
            (total-reward (+ base-reward bonus-reward education-bonus))
        )

        (asserts! (<= (+ (get claimed-amount heir-data) total-reward)
                     (get total-allocation heir-data))
                 ERR-INSUFFICIENT-BALANCE)

        ;; Verify contract has sufficient balance
        (asserts! (>= (stx-get-balance (as-contract tx-sender)) total-reward)
                 ERR-INSUFFICIENT-BALANCE)

        ;; Update milestone status
        (map-set milestones milestone-id (merge milestone { completed: true }))

        ;; Update heir's claimed amount and last activity
        (map-set heirs heir (merge heir-data { 
            claimed-amount: (+ (get claimed-amount heir-data) total-reward),
            last-activity: stacks-block-height
        }))

        ;; Transfer reward
        (as-contract
            (stx-transfer? total-reward tx-sender heir)))
    ))
)

(define-public (set-emergency-contact (new-contact principal))
    (begin
        (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)
        (var-set emergency-contact new-contact)
        (ok true)
    )
)

(define-public (update-vesting-period (new-period uint))
    (begin
        (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)
        (var-set minimum-vesting-period new-period)
        (ok true)
    )
)

(define-public (pause-contract)
    (begin
        (asserts! (or (is-contract-owner) 
                     (is-eq tx-sender (var-get emergency-contact)))
                 ERR-NOT-AUTHORIZED)
        (var-set active false)
        (ok true)
    )
)

(define-public (resume-contract)
    (begin
        (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)
        (var-set active true)
        (ok true)
    )
)

;; Initialize contract
(begin
    (var-set contract-owner tx-sender)
    (var-set active true)
    (var-set emergency-contact tx-sender)
)   