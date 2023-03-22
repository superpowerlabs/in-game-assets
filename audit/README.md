# Audit Report Summary

This repository contains the code audited by EtherAuthority, specifically the commit at https://github.com/superpowerlabs/in-game-assets/tree/b17e7203ab2853d7dad037b7f48257fef9932b43. The full audit report can be found [here](https://etherauthority.io/mobland-protocol-smart-contract-audit/), and a PDF version is also available in this folder.

We appreciate the professionalism and thoroughness of the audit conducted by EtherAuthority. However, we would like to address some of the issues mentioned in the report.

## Deposit ID Override Concern: GamePool.sol: \_depositFT()

This issue is not a vulnerability. The depositId is generated off-chain by the Game App and passed to the functions depositBud and depositSeed along with a signature to guarantee the correctness of the parameters passed to the contract.

For example, the depositSeed function is shown below:

```solidity
function depositSeed(
  uint256 amount,
  uint64 depositId,
  uint256 randomNonce,
  bytes calldata signature0
) external override {
  if (!isSignedByAValidator(0, 2, hashDeposit(_msgSender(), amount, depositId, randomNonce), signature0))
    revert invalidPrimarySignature();
  _saveSignatureAsUsed(signature0);
  _depositFT(SEED, amount, depositId, _msgSender());
}

```

The uniqueness of the depositId is ensured by the Game dApp, which also generates the signature, and by the fact that the signature is saved as used with \_saveSignatureAsUsed(signature0) and cannot be used again.

Since the smart contract must trust the signature accompanying the request, checking for the uniqueness of the depositId would only waste gas.

## Infinite Loops Possibility: NftFactory.sol: newSale()

There is no risk of infinite loops. The factory was designed as a generic factory for flexibility, but it was only used to sell two NFTs—Turf and Farm tokens—using two payment tokens—SEED and USDC.

As a result, we did not check the gasleft() in the loop to ensure the transaction would not run out of gas.

## Solhint Warnings

We initially used Solhint to check for lint warnings and errors. After the audit report, we integrated it into the pre-commit process, allowing commits only if Solhint returns no warnings and all tests pass. In both scenarios, we did not encounter any of the issues mentioned in the report.

Many of these issues appear to be false positives, as they involve errors such as:

```
NftFactory.sol:3565:64: Error: Parse error: mismatched input '('
expecting {';', '='}
```

A missing `;` would result in a compilation error, not a warning. And we would not be able to deploy the contracts and make the sale.
