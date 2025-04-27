// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import { ONFT721 } from "@layerzerolabs/onft-evm/contracts/onft721/ONFT721.sol";
import { ERC721 } from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import { SendParam, MessagingFee, MessagingReceipt } from "@layerzerolabs/onft-evm/contracts/onft721/interfaces/IONFT721.sol";

error ProfileFrozen(uint256 tokenId, address sender);

contract ProfileHub is ONFT721 {
    uint256 private _tokenIds;

    mapping(uint256 => bool) private _frozen;

    constructor(
        string memory _name,
        string memory _symbol,
        address _lzEndpoint,
        address _delegate
    ) ONFT721(_name, _symbol, _lzEndpoint, _delegate) {}

    function mint(address _to) public {
        _tokenIds++;
        uint256 newProfileId = _tokenIds;

        _mint(_to, newProfileId);
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                            VIEW                            */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    function isFrozen(uint256 _tokenId) public view returns (bool) {
        return _frozen[_tokenId];
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                         OVERRIDES                          */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    function _debit(address _from, uint256 _tokenId, uint32 /*_dstEid*/) internal virtual override {
        if (_from != ERC721.ownerOf(_tokenId)) revert OnlyNFTOwner(_from, ERC721.ownerOf(_tokenId));

        _frozen[_tokenId] = true;
    }

    function _credit(address /*_to*/, uint256 _tokenId, uint32 /*_srcEid*/) internal virtual override {
        _frozen[_tokenId] = false;
    }

    function _update(address to, uint256 tokenId, address auth) internal virtual override returns (address) {
        if (_frozen[tokenId]) revert ProfileFrozen(tokenId, auth);

        return super._update(to, tokenId, auth);
    }
}
