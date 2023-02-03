// SPDX-License-Identifier: Apache2
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "../wormhole-tunnel/WormholeTunnelUpgradeable.sol";

import "./IWormhole721.sol";

contract Wormhole721Upgradeable is IWormhole721, ERC721Upgradeable, WormholeTunnelUpgradeable {
  // solhint-disable-next-line func-name-mixedcase
  function __Wormhole721_init(string memory name, string memory symbol) internal virtual initializer {
    __WormholeTunnel_init();
    __ERC721_init(name, symbol);
  }

  function supportsInterface(bytes4 interfaceId)
    public
    view
    virtual
    override(ERC721Upgradeable, WormholeTunnelUpgradeable)
    returns (bool)
  {
    return type(IWormhole721).interfaceId == interfaceId || super.supportsInterface(interfaceId);
  }

  function wormholeTransfer(
    uint256 tokenID,
    uint16 recipientChain,
    bytes32 recipient,
    uint32 nonce
  ) public payable virtual override(IWormhole721, IWormholeTunnel) returns (uint64 sequence) {
    require(_isApprovedOrOwner(_msgSender(), tokenID), "ERC721: transfer caller is not owner nor approved");
    _burn(tokenID);
    return _wormholeTransferWithValue(tokenID, recipientChain, recipient, nonce, msg.value);
  }

  // Complete a transfer from Wormhole
  function wormholeCompleteTransfer(bytes memory encodedVm) public virtual override(IWormhole721, IWormholeTunnel) {
    (address to, uint256 tokenId) = _wormholeCompleteTransfer(encodedVm);
    _safeMint(to, tokenId);
  }

  uint256[50] private __gap;
}
