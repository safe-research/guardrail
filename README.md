# Guardrail

> [!WARNING]
> Code in this repository is not audited and may contain serious security holes. Use at your own risk.

![Guardrail](./guardrail-app/public/guardrail.png)

A guard contract restricting `DELEGATECALL` in safe smart account.

## Features

- Can immediately add a delegate if the guard is not enabled. Ideal for setting up any delegate which is intended to be used with delegate call (Ex: MultiSendCallOnly).
- Can schedule addition of a delegate after a delay.
- Can remove a delegate immediately (this happens without delay).
- With `v1.5.0` safe, it guards both Tx and Module Tx flow for delegate calls.

## Compatibility with Safe

- `v1.5.0`+ Safe version compatible with [Guardrail](./src/Guardrail.sol)
- For Demo purposes, we use [AppGuardrail](./src/test/AppGuardrail.sol)
    - This only covers the normal Tx Flow, does not guard against guard Tx flow.
    - This contains some helper function and data structures to show delegates in FE without any indexing

## Usage

### Contracts

#### Build

```shell
$ forge build
```

#### Test

```shell
$ forge test
```

#### Format

```shell
$ forge fmt
```

#### Gas Snapshots

```shell
$ forge snapshot
```

### Safe App

#### For running the app

```shell
$ npm run dev
```

## Improvements

- Delaying module addition
- Decoding multisend operation directly to Guardrail to avoid removal of guard, execution of delegate call transaction (requires valid signature) and enabling of guard
