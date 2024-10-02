# MEV Liquidators

This project demonstrates how to perform liquidations on various DeFi projects using Foundry. It includes liquidator contracts and test scripts for Compound V3, Init, and Silo protocols.

## Overview

MEV (Maximal Extractable Value) Liquidators is a collection of smart contracts and test scripts that simulate and execute liquidations on different DeFi protocols. This project serves as an educational resource and a starting point for developers interested in MEV and liquidation mechanisms.

## Project Structure

- `src/`: Contains the main contract implementations
  - `InitLiquidator.sol`: Liquidator contract for Init protocol
  - `SiloLiquidator.sol`: Liquidator contract for Silo protocol
- `test/`: Contains test scripts
  - `testCompoundV3Liquidator.t.sol`: Test script for Compound V3 liquidations
  - `testInitLiquidator.t.sol`: Test script for Init liquidations
  - `testSiloLiquidator.t.sol`: Test script for Silo liquidations

## Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation.html)

## Setup

1. Clone the repository:

   ```
   git clone https://github.com/alikonuk1/mev-liquidators.git
   cd mev-liquidators
   ```

2. Install dependencies:

   ```
   forge install
   ```

3. Set up environment variables:
   Create a `.env` file in the project root and add your private key:
   ```
   PRIVATE_KEY=your_private_key
   ```

## Usage

### Running Tests

To run all tests:

```
forge test
```

To run a specific test file:

```
forge test --match-path test/testCompoundV3Liquidator.t.sol
forge test --match-path test/testInitLiquidator.t.sol
forge test --match-path test/testSiloLiquidator.t.sol
```

### Simulating Liquidations

The test scripts simulate various scenarios:

1. Depositing assets
2. Borrowing against collateral
3. Simulating price drops
4. Executing liquidations
5. Verifying solvency and balance changes

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## Disclaimer

This project is for educational purposes only. Always exercise caution when interacting with DeFi protocols.

## License

This project is licensed under the MIT License.
