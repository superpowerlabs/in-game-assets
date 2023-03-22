# Audit report

The code in this repo — specifically the commit at https://github.com/superpowerlabs/in-game-assets/tree/b17e7203ab2853d7dad037b7f48257fef9932b43 — has been audited by EtherAuthority and you can find the report [here](https://etherauthority.io/mobland-protocol-smart-contract-audit/). Also, in this folder there is a Pdf version of the report.

## Misevaluated vulnerabilities

#### Page 21 — Deposit id override by any depositor: GamePool.sol: \_depositFT()

This is not a vulnerability.

The `depositId` is generated, off-chain, by the Game App and passed to the functions `depositBud` and `depositSeed` with a signature that guarantees the correctness of the parameters passed to the contract.

Look, for example, at the function depositSeed

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

The uniqueness of the `depositId` is guaranteed by the Game dApp, which also generates the signature, and by the fact that the signature is saved as used with `_saveSignatureAsUsed(signature0)` and cannot be used again.

Since the smart contract is not aware of the correctness of the `depositId` and must trust the signature coming with the request, checking for its uniqueness is only a waste of gas.

#### Page 25 — Infinite loops possibility: NftFactory.sol: newSale()

There is no risk of infinite loop. In fact, we built the factory as a generic factory to have more flexibility, but we used it only to sell 2 NFTs — Turf and Farm tokens — using only two payment tokens — SEED and USDC.

That is why we didn't check the gasleft() in the loop to be sure that the transaction will not run out of gas.

#### Page 69 - Solhint warnings

We used to launch Solhint to check for lint warnings and errors. After the report, we integrated it in the pre-commit process, to allow commits only if Solhint does not return any warning and all tests pass. Regardless, we did not have any of those issues.

BTW, most of those issues look like false positives to me because they are errors like

```
NftFactory.sol:3565:64: Error: Parse error: mismatched input '('
expecting {';', '='}
```

But a missing `;` would be a compilation error.
