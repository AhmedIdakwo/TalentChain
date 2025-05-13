# **TalentChain Protocol (TCP)**

**Version:** 1.0.0
**Language:** [Clarity](https://docs.stacks.co/docs/write-smart-contracts/clarity-overview)
**Blockchain:** [Stacks](https://www.stacks.co/) (secured by Bitcoin)

**TalentChain Protocol (TCP)** — A decentralized, fee-governed smart contract framework for managing talent-focused token minting and protocol economics.

---

## 📖 Overview

The **TalentChain Protocol (TCP)** is a consolidated Clarity smart contract for managing the core operations of a **Decentralized Talent Protocol (DTP)**. It defines the foundational fee structure, treasury handling, and versioning controls required to operate a scalable and secure talent-oriented decentralized application.

This smart contract is designed to be a **single-contract, simplified implementation**, with owner-only permissions for administrative operations. Ideal for MVPs or tightly-governed DAO environments.

---

## 🚀 Features

* **Minting Fee Management:** Configurable minting fee for user actions like token creation.
* **Transaction Fee Logic:** Adjustable fee percentage to support protocol sustainability.
* **DAO Treasury Accumulation:** Central fee collection for DAO usage and rewards.
* **Secure Withdrawals:** Only owner can withdraw funds; ideal for early governance stages.
* **Version Control:** Track and update the protocol version as features evolve.

---

## 🧾 Constants

| Name                      | Description                       | Default            |
| ------------------------- | --------------------------------- | ------------------ |
| `minting-fee`             | Fee to mint assets (in micro-STX) | `u1000000` (1 STX) |
| `transaction-fee-percent` | Fee taken on transactions         | `u1` (1%)          |
| `dao-treasury`            | Accumulated funds                 | `u0`               |
| `protocol-version`        | Semantic versioning of protocol   | `"1.0.0"`          |

---

## ⚙️ Public Functions

### 🔐 Owner-Only

* `update-minting-fee (uint)`
  Update the minting fee.

* `update-transaction-fee (uint)`
  Update transaction fee % (max 10%).

* `withdraw-treasury (amount uint, recipient principal)`
  Withdraw specified STX amount from treasury to a recipient.

* `update-protocol-version (string-ascii 10)`
  Change the protocol version.

### 💸 Treasury and Fees

* `collect-fee (amount uint)`
  Adds funds to treasury.

### 📖 Read-Only

* `get-minting-fee`
* `get-transaction-fee-percent`
* `get-treasury-balance`
* `get-protocol-version`

---

## 🧪 Error Codes

| Error      | Description                                      |
| ---------- | ------------------------------------------------ |
| `err u100` | Unauthorized: Only owner can perform this action |
| `err u101` | Not found (reserved for future use)              |
| `err u102` | Unauthorized access                              |
| `err u103` | Already exists (reserved for future use)         |
| `err u104` | Invalid parameters                               |
| `err u105` | Insufficient funds                               |

---

## 🔒 Security & Governance Notes

* All administrative functions are controlled by `tx-sender` at contract deployment time (owner-only).
* This is a **consolidated** (non-modular) design—governance mechanisms can be implemented externally or added in a future modular version.

---

## ✨ Future Improvements

* Modular governance system (DAO proposals, voting, multi-sig).
* Minting/token logic (currently out of scope in this contract).
* Role-based access control for admins, creators, and curators.
