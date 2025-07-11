# Guardrail

> [!WARNING]
> Code in this repository is not audited and may contain serious security holes. Use at your own risk.

![Guardrail](./guardrail-app/public/guardrail.png)

**Guardrail** is a security-focused guard contract that provides enhanced control over `DELEGATECALL` operations in Safe smart accounts. It implements a time-delayed allowlist system for delegate contracts, helping prevent unauthorized delegate calls while maintaining flexibility for legitimate use cases.

## Overview

Guardrail acts as a security layer for Safe smart accounts by:
- Restricting delegate calls to pre-approved contracts only
- Implementing time delays for adding new delegates (configurable)
- Allowing immediate removal of delegates when needed
- Supporting both transaction and module transaction flows in Safe v1.5.0+

## Key Features

- **Immediate Delegate Addition**: Add delegates instantly when the guard is not yet enabled - perfect for initial setup with contracts like MultiSendCallOnly
- **Time-Delayed Security**: Schedule addition of new delegates with a configurable delay period for enhanced security
- **Instant Removal**: Remove delegates immediately without delay when needed
- **Comprehensive Coverage**: Guards both transaction and module transaction flows in Safe v1.5.0+
- **Safe Integration**: Seamlessly integrates with Safe smart accounts as a guard contract

## Safe Compatibility

| Safe Version | Guardrail Contract | Coverage |
|-------------|-------------------|----------|
| v1.5.0+ | [Guardrail.sol](./src/Guardrail.sol) | Full (Tx + Module Tx flows) |
| Demo/Testing | [AppGuardrail.sol](./src/test/AppGuardrail.sol) | Limited (Tx flow only) |

### About AppGuardrail
- **Purpose**: Demo and testing only
- **Limitations**: Only covers normal transaction flow, does not guard module transactions
- **Features**: Includes helper functions and data structures for frontend integration without requiring indexing services

## Project Structure

```
├── src/                          # Smart contracts
│   ├── Guardrail.sol             # Main guard contract (production)
│   ├── MultiSendCallOnlyv2.sol   # Enhanced MultiSend implementation
│   ├── interfaces/               # Contract interfaces
│   └── test/                     # Test contracts and utilities
├── script/                       # Deployment scripts
├── test/                         # Contract tests
├── guardrail-app/                # React-based Safe App frontend
├── certora/                      # Formal verification specs
└── lib/                          # Dependencies (forge-std, OpenZeppelin, Safe)
```

## Installation

### Smart Contracts

```shell
# Clone the repository
git clone <repository-url>
cd guardrail

# Install Foundry dependencies
forge install

# Build contracts
forge build
```

### Safe App Frontend

```shell
# Navigate to the app directory
cd guardrail-app

# Install dependencies
npm install

# Start development server
npm run dev
```

## Usage

### Smart Contract Development

#### Build Contracts

```shell
forge build
```

#### Run Tests

```shell
forge test
```

#### Run Tests with Verbosity

```shell
forge test -vv
```

#### Format Code

```shell
forge fmt
```

#### Generate Gas Snapshots

```shell
forge snapshot
```

#### Deploy Contracts

```shell
# Deploy to testnet (example: Sepolia) AppGuardrail
forge script ./script/AppGuardrail.s.sol:AppGuardrailScript --broadcast -vvvv --chain sepolia --rpc-url sepolia --verify
```

### Safe App Development

#### Start Development Server

```shell
cd guardrail-app
npm run dev
```

The app will be available at `http://localhost:3000`

#### Build for Production

```shell
npm run build
```

#### Run Linting

```shell
npm run lint
npm run lint:fix  # Auto-fix issues
```

#### Format Code

```shell
npm run format
npm run format:check  # Check formatting
```

## Security Considerations

> [!IMPORTANT]
> Always review and test thoroughly before using in production environments.

- **Time Delays**: Configure appropriate delay periods based on your security requirements
- **Delegate Verification**: Only allow trusted contracts as delegates
- **Guard Removal**: Guard removal is also time-delayed for security
- **Module Guards**: Ensure module guard functionality is properly configured for comprehensive protection

## Roadmap & Future Improvements

- **Module Addition Delays**: Implement time delays for module additions to enhance security
- **Enhanced MultiSend Integration**: Direct decoding of multisend operations to prevent guard bypass attacks
- **Gas Optimization**: Further optimize contract gas usage
