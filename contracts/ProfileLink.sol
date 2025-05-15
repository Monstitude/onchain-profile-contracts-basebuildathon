// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import { ONFT721 } from "@layerzerolabs/onft-evm/contracts/onft721/ONFT721.sol";
import { ERC721 } from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import { SendParam, MessagingFee, MessagingReceipt } from "@layerzerolabs/onft-evm/contracts/onft721/interfaces/IONFT721.sol";
import { ONFT721MsgCodec } from "@layerzerolabs/onft-evm/contracts/onft721/libs/ONFT721MsgCodec.sol";
import { ONFTComposeMsgCodec } from "@layerzerolabs/onft-evm/contracts/libs/ONFTComposeMsgCodec.sol";
import { IOAppMsgInspector } from "@layerzerolabs/oapp-evm/contracts/oapp/interfaces/IOAppMsgInspector.sol";
import { ProfileLib } from "./ProfileLib.sol";
import { Origin } from "@layerzerolabs/oapp-evm/contracts/oapp/OApp.sol";

contract ProfileLink is ONFT721 {
    using ONFT721MsgCodec for bytes;
    using ONFT721MsgCodec for bytes32;

    constructor(
        string memory _name,
        string memory _symbol,
        address _lzEndpoint,
        address _delegate
    ) ONFT721(_name, _symbol, _lzEndpoint, _delegate) {}

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                          INTERNAL                          */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    function _determineMessageType(bytes memory extractedData) internal pure returns (ProfileLib.MessageType) {
        // Extract the first byte or use a specific logic for type determination
        uint8 typeByte = uint8(extractedData[0]); // Get the first byte
        if (typeByte == 0) {
            return ProfileLib.MessageType.NFT_TRANSFER;
        } else {
            return ProfileLib.MessageType.CREATE_PROFILE;
        }
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                         OVERRIDES                          */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /**
     * @dev Internal function to build the message and options.
     * @param _sendParam The parameters for the send() operation.
     * @return message The encoded message.
     * @return options The encoded options.
     */
    function _buildMsgAndOptions(
        SendParam calldata _sendParam
    ) internal view virtual override returns (bytes memory message, bytes memory options) {
        if (_sendParam.to == bytes32(0)) revert InvalidReceiver();
        bool hasCompose;
        (message, hasCompose) = ONFT721MsgCodec.encode(_sendParam.to, _sendParam.tokenId, _sendParam.composeMsg);
        message = abi.encodePacked(ProfileLib.MessageType.NFT_TRANSFER, message);
        uint16 msgType = hasCompose ? SEND_AND_COMPOSE : SEND;

        options = combineOptions(_sendParam.dstEid, msgType, _sendParam.extraOptions);

        // @dev Optionally inspect the message and options depending if the OApp owner has set a msg inspector.
        // @dev If it fails inspection, needs to revert in the implementation. ie. does not rely on return boolean
        address inspector = msgInspector; // caches the msgInspector to avoid potential double storage read
        if (inspector != address(0)) IOAppMsgInspector(inspector).inspect(message, options);
    }

    /**
     * @dev Internal function to handle the receive on the LayerZero endpoint.
     * @param _origin The origin information.
     *  - srcEid: The source chain endpoint ID.
     *  - sender: The sender address from the src chain.
     *  - nonce: The nonce of the LayerZero message.
     * @param _guid The unique identifier for the received LayerZero message.
     * @param _message The encoded message.
     * @dev _executor The address of the executor.
     * @dev _extraData Additional data.
     */
    function _lzReceive(
        Origin calldata _origin,
        bytes32 _guid,
        bytes calldata _message,
        address /*_executor*/, // @dev unused in the default implementation.
        bytes calldata /*_extraData*/ // @dev unused in the default implementation.
    ) internal virtual override {
        // Determine the message type based on the extracted data
        ProfileLib.MessageType messageType = _determineMessageType(_message);

        // Use the extracted message type for further logic
        if (messageType == ProfileLib.MessageType.NFT_TRANSFER) {
            // Extract the first 32 bytes (Message Type)
            address toAddress = bytes32(_message[1:33]).bytes32ToAddress();
            uint256 tokenId = uint256(bytes32(_message[33:65]));

            _credit(toAddress, tokenId, _origin.srcEid);

            if (_message.isComposed()) {
                bytes memory composeMsg = ONFTComposeMsgCodec.encode(
                    _origin.nonce,
                    _origin.srcEid,
                    _message.composeMsg()
                );
                // @dev As batching is not implemented, the compose index is always 0.
                // @dev If batching is added, the index will need to be tracked.
                endpoint.sendCompose(toAddress, _guid, 0 /* the index of composed message*/, composeMsg);
            }

            emit ONFTReceived(_guid, _origin.srcEid, toAddress, tokenId);
        }
    }
}
