# 🎟️ Cyfrin SC Lottery (Raffle)

A Foundry-based refresher project implementing a simple raffle (lottery) smart contract using Chainlink VRF v2.5 for secure randomness and automated workflows. Designed for learning, testing, and quick iterations.

---

## ✨ Key Features

- ✅ Raffle where players enter by paying a fixed entrance fee.
- 🔐 Chainlink VRF integration (`VRFConsumerBaseV2Plus` / `VRFV2PlusClient`) for provable randomness.
- 🧪 Unit tests with Foundry + `forge-std` and Chainlink VRF mocks.
- 🧰 `HelperConfig` for local / CI configuration.

---

## ⚙️ Tech Stack

- **Solidity** 0.8.19
- **Foundry** (forge, anvil)
- **Chainlink** contracts & VRF mocks
- **forge-std** Test utilities

---

## 📁 Project Structure

- `src/`
  - `raffle.sol` — Main Raffle contract (enterRaffle, pickWinner, request/fulfill randomness)
- `test/`
  - `unit/Raffle.t.sol` — Unit tests using mocks
- `script/`
  - `HelperConfig.s.sol` — Network/test configuration helpers

---

## 🚀 Quick Start

Prerequisites

- Foundry installed: `curl -L https://foundry.paradigm.xyz | bash && foundryup`
- Git and macOS terminal (tested on macOS)

Install deps

```bash
forge install
```

Run tests

```bash
forge test -vv
```

Run a specific test

```bash
forge test -m testEventIsEmittedAfterAddingPlayer -vv
```

---

## 🧪 Testing notes & common gotchas

- ⚠️ If you see:

  ```
  unrecognized function selector ... for contract ... which has no fallback function
  ```

  it means the VRF mock tried to call a non‑exposed callback on your contract. Solutions:

  - Add the external bridge the mock expects (example below).
  - Use a mock that matches VRF v2.5 interfaces.

- Example bridge to add to `Raffle.sol`:

```solidity
function rawFulfillRandomWords(uint256 requestId, uint256[] calldata randomWords) external {
    require(msg.sender == address(s_vrfCoordinator), "Only coordinator can fulfill");
    fulfillRandomWords(requestId, randomWords);
}
```

- Ensure VRF subscriptions are funded in tests (see `setUp()` usage of `fundSubscription`).

---

## 📜 Contract overview (Raffle.sol)

- `enterRaffle()` — payable; adds player and emits `EnteredRaffle`.
- `pickWinner()` — checks timing and triggers randomness request.
- `requestRandomWords()` — builds `VRFV2PlusClient.RandomWordsRequest` and forwards to coordinator.
- `fulfillRandomWords()` — internal override to handle coordinator fulfillment.

---

## 🤝 Contributing

Contributions welcome. Open issues or PRs for bug fixes, test coverage, or feature enhancements.

---

## 🧾 License

MIT
