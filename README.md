🌟 AdaptiveAdNet 🌟
-------------------

**Decentralized Advertising Network with Dynamic Pricing and Performance Tracking**

* * * * *

### 📘 Overview

**AdaptiveAdNet** is a sophisticated **Clarity Smart Contract** designed for a **decentralized, autonomous advertising network (DAAN)** built on the Stacks blockchain. It implements core business logic for real-time bidding, campaign management, publisher ad slot creation, and performance tracking (Impressions, Clicks, Conversions, CTR). The system utilizes the **STX token** for all transactions, including budget allocation and publisher payments, ensuring transparent, immutable, and auditable ad spending.

The contract manages relationships between **Advertisers** (who fund campaigns and place bids) and **Publishers** (who host ad slots and report events). It features dynamic bid management, budget exhaustion control, and a customizable platform fee system managed by the contract owner.

* * * * *

### ✨ Features

-   **Advertiser & Campaign Management:** Allows users to register as Advertisers, create campaigns with specific budgets and default bids, and manage their campaign state (pause/resume).

-   **Publisher & Ad Slot Management:** Enables users to register as Publishers and create ad slots with a defined minimum bid requirement.

-   **Bid Management:** Advertisers can place bids on specific ad slots, subject to meeting the slot's minimum bid requirement.

-   **Decentralized Event Recording:** Publishers are responsible for recording **Impressions** and **Clicks** against active campaigns and slots, providing auditable performance data.

-   **Automated Click Payment (Cost-Per-Click):** The `record-click` function automatically handles the **transfer of STX** from the campaign's reserved contract balance to the Publisher, deducting the platform fee in the process.

-   **Budget Control:** Campaigns are automatically paused if the remaining budget is insufficient to cover the cost of the next recorded click, preventing overspending.

-   **Performance Tracking (KPIs):** Read-only functions allow for the calculation of critical campaign metrics like the **Click-Through Rate (CTR)**.

-   **Admin Controls:** The contract owner can dynamically adjust the **platform fee percentage** and the network-wide **minimum bid amount**.

* * * * *

### ⚙️ Contract Architecture

The contract's state is maintained across several key variables and data maps.

#### 1\. Constants & Errors

| Constant | Value | Description |
| --- | --- | --- |
| `contract-owner` | `tx-sender` | The principal who deployed the contract. |
| `err-owner-only` | `u100` | Authorization error for admin functions. |
| `err-not-found` | `u101` | Entity ID (Campaign, Slot) or Principal not found. |
| `err-already-exists` | `u102` | Principal is already registered (Advertiser or Publisher). |
| `err-insufficient-funds` | `u103` | Campaign budget is exhausted or close to exhaustion. |
| `err-unauthorized` | `u104` | Sender is not the owner of the entity (e.g., campaign/slot). |
| `err-invalid-params` | `u105` | Invalid input (e.g., bid too low, fee too high). |

#### 2\. Data Variables (Dynamic State)

| Variable | Type | Initial Value | Description |
| --- | --- | --- | --- |
| `platform-fee-percentage` | `uint` | `u5` (5%) | Percentage taken by the platform on every click payment (Max 20%). |
| `min-bid-amount` | `uint` | `u1000000` | The absolute minimum allowed bid in **microSTX** (1 STX). |
| `campaign-counter` | `uint` | `u0` | Global counter for generating unique campaign IDs. |
| `slot-counter` | `uint` | `u0` | Global counter for generating unique ad slot IDs. |

#### 3\. Data Maps

| Map Name | Key | Value | Description |
| --- | --- | --- | --- |
| `advertisers` | `principal` | `{ total-spent: uint, active-campaigns: uint, reputation-score: uint }` | Stores meta-data for all registered advertisers. |
| `campaigns` | `uint` (Campaign ID) | `{ advertiser: principal, name: (string-ascii 50), budget: uint, spent: uint, bid-amount: uint, impressions: uint, clicks: uint, conversions: uint, active: bool, created-at: uint }` | Core data for each advertising campaign. |
| `publishers` | `principal` | `{ total-earned: uint, active-slots: uint, reputation-score: uint }` | Stores meta-data for all registered publishers. |
| `ad-slots` | `uint` (Slot ID) | `{ publisher: principal, name: (string-ascii 50), min-bid: uint, impressions: uint, clicks: uint, active: bool, created-at: uint }` | Core data for each ad placement slot. |
| `campaign-slot-bids` | `{campaign-id: uint, slot-id: uint}` | `{ bid-amount: uint, active: bool }` | Records a campaign's active bid on a specific ad slot. |

* * * * *

### 🚀 Public Function Reference

#### Advertiser Operations

| Function | Parameters | Returns | Description |
| --- | --- | --- | --- |
| `register-advertiser` | `()` | `(response bool uint)` | Registers the caller. Fails if already registered. |
| `create-campaign` | `(name (string-ascii 50), budget uint, bid-amount uint)` | `(response uint uint)` | Creates a new campaign. **Requires a transfer of `budget` STX to the contract** via `stx-transfer?`. Fails if `bid-amount` is below `min-bid-amount`. |
| `update-campaign-bid` | `(campaign-id uint, new-bid-amount uint)` | `(response { ... } uint)` | Updates the default bid amount for an existing campaign. Owner-only. |
| `pause-campaign` | `(campaign-id uint)` | `(response { ... } uint)` | Sets the campaign's `active` status to `false`. Owner-only. |
| `resume-campaign` | `(campaign-id uint)` | `(response { ... } uint)` | Sets the campaign's `active` status to `true`, provided it still has budget left. Owner-only. |

#### Publisher Operations

| Function | Parameters | Returns | Description |
| --- | --- | --- | --- |
| `register-publisher` | `()` | `(response bool uint)` | Registers the caller. Fails if already registered. |
| `create-ad-slot` | `(name (string-ascii 50), min-bid uint)` | `(response uint uint)` | Creates a new ad slot. Fails if `min-bid` is below `min-bid-amount`. |
| `record-impression` | `(campaign-id uint, slot-id uint)` | `(response { ... } uint)` | **Must be called by the Slot Publisher.** Increments impression counts for both the campaign and the slot. |
| `place-bid` | `(campaign-id uint, slot-id uint)` | `(response { ... } uint)` | **Must be called by the Campaign Advertiser.** Establishes an active bid of the campaign's default bid amount on the specified slot. Fails if the bid is less than the slot's `min-bid`. |

#### Core Transaction Logic (Newly-Added)

| Function | Parameters | Returns | Description |
| --- | --- | --- | --- |
| `record-click` | `(campaign-id uint, slot-id uint)` | `(response bool uint)` |

**Must be called by the Slot Publisher.** This is the primary monetization function:

1\. Checks budget availability.

2\. Calculates `platform-fee` and `publisher-payment`.

3\. **Transfers `publisher-payment` STX from the contract to the Publisher** using `as-contract (stx-transfer? ...)`.

4\. Updates campaign (`clicks`, `spent`) and slot (`clicks`) counters.

5\. Updates `total-earned` for Publisher and `total-spent` for Advertiser.

6\. **Automatically pauses the campaign** if budget is exhausted after the transaction.

#### Admin Functions

| Function | Parameters | Returns | Description |
| --- | --- | --- | --- |
| `set-platform-fee` | `(new-fee uint)` | `(response uint uint)` | Allows the `contract-owner` to set a new platform fee percentage (Max 20%). |
| `set-min-bid` | `(new-min-bid uint)` | `(response uint uint)` | Allows the `contract-owner` to set a new minimum bid amount for the network. |

* * * * *

### 📊 Read-Only Functions

These functions provide transparent access to the contract's state and calculated performance metrics.

| Function | Parameters | Returns | Description |
| --- | --- | --- | --- |
| `get-campaign` | `(campaign-id uint)` | `(optional { ... } )` | Retrieves all data for a specific campaign. |
| `get-ad-slot` | `(slot-id uint)` | `(optional { ... } )` | Retrieves all data for a specific ad slot. |
| `get-advertiser` | `(advertiser principal)` | `(optional { ... } )` | Retrieves data for a specific advertiser. |
| `get-publisher` | `(publisher principal)` | `(optional { ... } )` | Retrieves data for a specific publisher. |
| `get-bid` | `(campaign-id uint, slot-id uint)` | `(optional { ... } )` | Retrieves the active bid between a campaign and a slot. |
| `get-platform-fee` | `()` | `uint` | Retrieves the current platform fee percentage. |
| `get-min-bid-amount` | `()` | `uint` | Retrieves the current network-wide minimum bid amount. |
| `get-campaign-performance` | `(campaign-id uint)` | `(response { ... } uint)` | Calculates and returns key performance indicators, including **CTR (Click-Through Rate)**. CTR is returned in basis points (i.e., `10000` multiplier for precision). |

* * * * *

### 🛠️ Private Helper Function

| Function | Parameters | Returns | Description |
| --- | --- | --- | --- |
| `calculate-platform-fee` | `(amount uint)` | `uint` | Calculates the platform fee amount from a given `bid-amount` based on the current `platform-fee-percentage`. Formula: platform_fee=(amount×platform_fee_percentage)/100 |

* * * * *

### 🤝 Contribution

We welcome contributions to the **AdaptiveAdNet** smart contract.

#### Security

Security is the highest priority. If you find a security vulnerability, please do not open a public issue. Instead, contact the contract owner directly.

#### Development Guidelines

1.  **Clarity Language:** Ensure all new functions and data structures adhere to the Clarity smart contract language specifications and best practices.

2.  **Naming Conventions:** Use kebab-case for function names (`function-name`) and clarity variable types (e.g., `uint`).

3.  **Error Handling:** All public functions must return a `response` type, utilizing the defined error codes for failure states. Use `unwrap!` or `try!` appropriately for map lookups and internal transactions.

4.  **Testing:** All contributions must be accompanied by comprehensive unit tests covering success paths, edge cases, and all failure conditions (error codes).

* * * * *

### ⚖️ License

**AdaptiveAdNet** is released under the **MIT License**.

```
MIT License

Copyright (c) 2025 AdaptiveAdNet Contributors

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

```

* * * * *

### 🔮 Future Enhancements

-   **Conversion Tracking:** Implement a `record-conversion` function to update the `conversions` field in the `campaigns` map.

-   **Reputation System:** Enhance the `reputation-score` fields in `advertisers` and `publishers` maps, tying them to performance metrics (e.g., CTR) and reliability (e.g., budget fulfillment).

-   **Dynamic Bidding Algorithm:** Implement a private function that uses historical performance data (CTR, conversions) to suggest or automatically adjust the `bid-amount` to optimize Advertiser ROI.

-   **Withdraw Function:** A dedicated function to allow the `contract-owner` to withdraw the collected `platform-fee` STX from the contract's balance.
