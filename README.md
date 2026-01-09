# 🎟️ Cyfrin SC Lottery (Raffle)

A Foundry-based refresher project implementing a simple raffle (lottery) smart contract using Chainlink VRF v2.5 for secure randomness and automated workflows. Designed for learning, testing, and quick iterations.

---

## ✨ Key Features

- ✅ Raffle where players enter by paying a fixed entrance fee.
- 🔐 Chainlink VRF v2.5 integration (`VRFConsumerBaseV2Plus` / `VRFV2PlusClient`) for provable randomness.
- 🤖 Automated winner selection via Chainlink Keepers (checkUpkeep / performUpkeep pattern).
- 🧪 Unit tests with Foundry + `forge-std` and Chainlink VRF mocks.
- 🧰 `HelperConfig` for local / CI configuration.

---

## ⚙️ Tech Stack

- **Solidity** 0.8.19
- **Foundry** (forge, anvil)
- **Chainlink** contracts & VRF v2.5 mocks
- **forge-std** Test utilities

---

## 📁 Project Structure

- `src/`
  - `raffle.sol` — Main Raffle contract (enterRaffle, checkUpkeep, performUpkeep, request/fulfill randomness)
- `test/`
  - `unit/Raffle.t.sol` — Unit tests using Chainlink mocks
  - `integration/Interactions.t.sol` — Integration tests for HelperConfig, Interactions, and Deploy scripts
- `script/`
  - `HelperConfig.s.sol` — Network/test configuration helpers
  - `Interactions.s.sol` — Create/fund subscriptions and add consumers
  - `DeployRaffle.s.sol` — Deploys Raffle and registers it as a VRF consumer

---

## 🚀 Quick Start

### Prerequisites

- Foundry installed: `curl -L https://foundry.paradigm.xyz | bash && foundryup`
- Git and macOS terminal (tested on macOS)

### Install deps

```bash
forge install
```

### Run tests

```bash
forge test -vv
```

### Run a specific test

```bash
forge test --mt testEventIsEmittedAfterAddingPlayer -vv
```

### Run integration tests

```bash
forge test --match-path test/integration/Interactions.t.sol -vv
```

---

## 🧪 Testing notes & common gotchas

- ⚠️ **VRF Coordinator Consumer Error:**

  If you see:

  ```
  InvalidConsumer(...)
  ```

  It means the Raffle contract is not registered as a consumer on the subscription. Solutions:

  - Ensure `fundSubscription()` is called in `setUp()`.
  - Verify the subscription ID matches the one used in the Raffle constructor.
  - Add the Raffle contract as a consumer before calling `requestRandomWords()`.

- ⚠️ **Unrecognized Function Selector:**

  If you see:

  ```
  unrecognized function selector ... for contract ... which has no fallback function
  ```

  It means the VRF mock tried to call a non‑exposed callback on your contract. Solutions:

  - Ensure `fulfillRandomWords()` is properly overridden from `VRFConsumerBaseV2Plus`.
  - Use the correct mock version matching VRF v2.5 interfaces.

- Ensure VRF subscriptions are funded in local tests (see `setUp()` usage of `fundSubscription`).
- When forking Sepolia, don't call mock-only functions like `fundSubscription()` or `addConsumer()` on the real coordinator. Use LINK `transferAndCall` to fund and ensure the deployed consumer is registered on your real subscription.

---

## 📜 Contract overview (Raffle.sol)

- `enterRaffle()` — payable; adds player and emits `EnteredRaffle`.
- `checkUpkeep()` — view function to check if upkeep (winner selection) conditions are met.
- `performUpkeep()` — checks conditions and triggers randomness request via VRF coordinator.
- `requestRandomWords()` — builds `VRFV2PlusClient.RandomWordsRequest` and forwards to coordinator.
- `fulfillRandomWords()` — internal override to handle coordinator fulfillment; picks winner and transfers balance.

---

## 🤝 Contributing

Contributions welcome. Open issues or PRs for bug fixes, test coverage, or feature enhancements.

---

## 🧾 License

MIT
