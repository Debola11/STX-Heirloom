# STX-Heirloom -   Wealth Trust Smart Contract

## Overview

The **Intergenerational Wealth Trust (IWT)** is a Clarity smart contract designed to manage long-term wealth distribution across generations using milestone-based vesting and guardian oversight mechanisms. It ensures secure and controlled release of assets to designated heirs based on predefined conditions like age, education milestones, and time-based vesting.

This contract supports:

* Milestone-based STX rewards
* Guardian approvals for sensitive actions
* Education bonuses
* Vesting period enforcement
* Emergency controls

---

## 🏗️ Key Concepts

### Heirs

A designated recipient of trust funds, registered by the contract owner. Each heir has:

* Birth block height (used to calculate age)
* Total allocation
* Claimed amount
* Guardian (optional)
* Education bonus
* Status (e.g., `active`)
* Vesting start and last activity block

### Milestones

Custom achievements (e.g., age, education) defined by the owner. Each has:

* Age requirement
* Optional deadline
* Bonus multiplier
* Optional guardian approval requirement

### Guardians

Optional appointed supervisors per heir who must approve specific milestone claims.

---

## ✅ Features

* **Flexible Milestone Logic**: Set custom descriptions, age requirements, reward amounts, deadlines, and bonuses.
* **Guardian Approvals**: Secure guardian validation for milestone claims.
* **Education Bonuses**: Additional incentives for academic achievement.
* **Emergency Pausing**: Emergency contact can pause the contract.
* **Vesting Enforcement**: Enforces a vesting period before any funds can be claimed.
* **Comprehensive Validation**: All inputs and states are validated for integrity and security.

---

## 🛠️ Functions

### 👤 Heir Management

* `add-heir` – Adds a new heir with allocation, birth block, and optional guardian.
* `update-guardian` – Assigns or updates an heir's guardian.
* `add-education-bonus` – Adds a bonus for educational achievement.

### 🏁 Milestone System

* `add-milestone` – Creates a new milestone with detailed rules.
* `approve-milestone` – Guardian or owner can approve milestone if required.
* `claim-milestone` – Heir claims milestone reward, validating age, guardian, status, vesting, etc.

### 🧠 Contract Administration

* `pause-contract` / `resume-contract` – Temporarily disable or resume the contract.
* `set-emergency-contact` – Updates emergency contact who can pause the contract.
* `update-vesting-period` – Adjusts the minimum vesting period.

### 🕵️ Read-only Views

* `get-heir-info` – Returns complete info on an heir.
* `get-milestone` – Returns milestone data.
* `get-vesting-status` – Checks if heir is vested.
* `calculate-age` – Calculates current age from birth block height.
* `get-guardian-approval` – Shows guardian approval status for a milestone.

---

## 📑 Constants & Error Codes

### Constants

* `MINIMUM_ALLOCATION`: 1 STX
* `MINIMUM_AGE_REQUIREMENT`: 16 years
* `MAXIMUM_AGE_REQUIREMENT`: 100 years
* `MAXIMUM_BONUS_MULTIPLIER`: 5x (500%)
* `BLOCKS_PER_DAY`: 144 (approx.)
* `minimum-vesting-period`: 52,560 blocks (\~1 year)

### Error Codes

Custom errors like:

* `ERR-NOT-AUTHORIZED`
* `ERR-ALREADY-INITIALIZED`
* `ERR-INVALID-AGE`
* `ERR-INSUFFICIENT-BALANCE`
* `ERR-MILESTONE-NOT-FOUND`
  ... and more (see contract for full list).

---

## 🔒 Security Considerations

* All state-changing functions check contract status (`active`) and enforce access control.
* Guardians and owners are the only ones allowed to approve or alter sensitive records.
* Funds are only transferred after full validation of eligibility and contract balance.
* Emergency pause available for halting operations if needed.

---
