// SPDX-License-Identifier: Apache2
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "../WormholeTunnel.sol";

contract BridgeableERC721Mock is ERC721, WormholeTunnel {
  uint256 public nextTokenId = 1;
  bool public isOnPrimaryChain;

  constructor(bool isOnPrimaryChain_) ERC721("Cross-chain NFT", "xNFT") {
    // this should be launched only for the token on the primary chain
    isOnPrimaryChain = isOnPrimaryChain_;
  }

  //  function _beforeTokenTransfer(address from, address to, uint256 tokenId)
  //  internal
  //  override(ERC721)
  //  {
  //    super._beforeTokenTransfer(from, to, tokenId);
  //  }

  function supportsInterface(bytes4 interfaceId) public view override(WormholeTunnel, ERC721) returns (bool) {
    return super.supportsInterface(interfaceId);
  }

  function mintNft(address to) external onlyOwner {
    require(isOnPrimaryChain, "Can mint only on primary chain");
    _safeMint(to, nextTokenId++);
  }

  function wormholeTransfer(
    uint256 payload,
    uint16 recipientChain,
    bytes32 recipient,
    uint32 nonce
  ) public payable virtual override whenNotPaused returns (uint64 sequence) {
    require(ownerOf(payload) == _msgSender(), "ERC721: transfer caller is not the owner");
    _burn(payload);
    return _wormholeTransferWithValue(payload, recipientChain, recipient, nonce, msg.value);
  }

  // Complete a transfer from Wormhole
  function wormholeCompleteTransfer(bytes memory encodedVm) public virtual override {
    // solhint-disable-next-line
    // here we mock
    (address to, uint256 payload) = abi.decode(encodedVm, (address, uint256));
    _safeMint(to, payload);
  }

  function getFakeEvm(address to, uint256 payload) public pure returns (bytes memory) {
    return abi.encode(to, payload);
  }
}
