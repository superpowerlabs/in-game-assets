// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

// Authors: Francesco Sullo <francesco@sullo.co>

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/cryptography/ECDSAUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract Signable is Initializable, OwnableUpgradeable {
  using AddressUpgradeable for address;
  using ECDSAUpgradeable for bytes32;

  event ValidatorSet(uint256 id, address validator);

  mapping(uint256 => address) private _validators;

  // solhint-disable-next-line
  function __Signable_init() internal initializer {
    __Ownable_init();
  }

  function setValidator(uint256 id, address validator) external onlyOwner {
    require(validator != address(0), "Signable: no address zero");
    _validators[id] = validator;
    emit ValidatorSet(id, validator);
  }

  function getValidator(uint256 id) external view returns (address) {
    return _validators[id];
  }

  function isValidator(address validator, uint256 maxId) external view returns (bool) {
    for (uint256 i = 0; i <= maxId; i++) {
      if (_validators[i] == validator) {
        return true;
      }
    }
    return false;
  }

  /** @dev how to use it:
    require(
      isSignedByValidator(0, encodeForSignature(to, tokenType, lockedFrom, lockedUntil, mainIndex, tokenAmountOrID), signature),
      "WormholeBridge: invalid signature"
    );
  */

  // this is called internally and externally by the web3 app to test a validation
  function isSignedByValidator(
    uint256 id,
    bytes32 hash,
    bytes memory signature
  ) public view returns (bool) {
    return _validators[id] != address(0) && _validators[id] == hash.recover(signature);
  }

  function isSignedByAValidator(
    uint256 id0,
    uint256 id1,
    bytes32 hash,
    bytes memory signature
  ) public view returns (bool) {
    return isSignedByValidator(id0, hash, signature) || isSignedByValidator(id1, hash, signature);
  }
}
