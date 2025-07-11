# Guardrail App

A React application for interacting with the Guardrail smart contract system for Safe wallets.

## Features

- 🔐 **Safe Integration**: Seamlessly integrate with Safe wallets using the Safe Apps SDK
- 🛡️ **Guard Management**: Enable/disable transaction guards for enhanced security
- 👥 **Delegate Management**: Configure delegate allowances for authorized transactions
- ⏰ **Scheduled Operations**: Schedule guard removal with time delays for security
- 🎨 **Modern UI**: Built with Material-UI for a polished user experience

## Getting Started

### Prerequisites

- Node.js (v18 or higher)
- npm or yarn
- A Safe wallet for testing

### Installation

1. Clone the repository and navigate to the app directory:

```bash
cd guardrail-app
```

2. Install dependencies:

```bash
npm install
```

### Development

Start the development server:

```bash
npm run dev
```

The app will be available at `http://localhost:3000`.

### Building for Production

```bash
npm run build
```

### Deployment

The app is designed to be deployed as a Safe App. Configure the `VITE_BASE_URL` environment variable for your deployment path.

## Architecture

The application consists of:

- **App.tsx**: Main application component with Safe integration
- **Smart Contract Interface**: Ethers.js interface for Guardrail contract interactions
- **State Management**: React hooks for managing application state
- **Type Safety**: Full TypeScript support with strict type checking

## Safe App Integration

This app integrates with Safe wallets through the Safe Apps SDK, allowing users to:

1. **Activate/Deactivate Guards**: Control transaction guard functionality
2. **Manage Delegates**: Set up authorized delegates for transactions
3. **Schedule Operations**: Use time-locked operations for enhanced security

## Smart Contract Interactions

The app interacts with the Guardrail smart contract to:

- Query current guard status
- Manage delegate allowances
- Schedule guard removal operations
- Execute immediate delegate allowances

## Security Considerations

- All smart contract addresses are configurable in constants
- Type-safe contract interactions using ethers.js
- Proper error handling and user feedback
- Input validation for all user inputs
