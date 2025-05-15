// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import { ProfileHub } from "./ProfileHub.sol";

error NameRequired();

error InvalidName(string name);

contract Username {
    uint256 private nonce;

    mapping(string => mapping(uint16 => address)) public nameTaken; // name => number => profile no
    mapping(address => string) public addressToUsername;

    event UsernameRegistered(address indexed user, string fullUsername);
    event UsernameUpdated(address indexed user, string previousUsername, string currentUsername);

    function registerUsername(address user, string calldata name) internal {
        string memory sanitizedName = sanitize(name);

        require(bytes(sanitizedName).length > 0, "Name required");
        require(bytes(addressToUsername[user]).length == 0, "Already registered");

        uint16 randomNumber;
        string memory fullUsername;
        bool assigned = false;

        for (uint8 i = 0; i < 10; i++) {
            randomNumber = _getRandomDigits(sanitizedName);
            if (nameTaken[sanitizedName][randomNumber] == address(0)) {
                nameTaken[sanitizedName][randomNumber] = user;
                fullUsername = string(abi.encodePacked(sanitizedName, ".", _uintToStr(randomNumber)));
                addressToUsername[user] = fullUsername;
                emit UsernameRegistered(user, fullUsername);
                assigned = true;
                break;
            }
        }

        require(assigned, "Failed to assign username after 10 tries");
    }

    function changeUsername(string calldata name) external {
        string memory sanitizedName = sanitize(name);
        string memory previousName = addressToUsername[msg.sender];

        require(bytes(addressToUsername[msg.sender]).length > 0, "Register username first!");

        uint16 randomNumber;
        string memory fullUsername;
        bool assigned = false;

        for (uint8 i = 0; i < 10; i++) {
            randomNumber = _getRandomDigits(sanitizedName);
            if (nameTaken[sanitizedName][randomNumber] == address(0)) {
                nameTaken[sanitizedName][randomNumber] = msg.sender;
                fullUsername = string(abi.encodePacked(sanitizedName, ".", _uintToStr(randomNumber)));
                addressToUsername[msg.sender] = fullUsername;
                emit UsernameUpdated(msg.sender, previousName, fullUsername);
                assigned = true;
                break;
            }
        }

        require(assigned, "Failed to assign username after 10 tries");
    }

    function sanitize(string memory name) public pure returns (string memory) {
        bytes memory b = bytes(name);
        bytes memory result = new bytes(b.length);

        for (uint256 i = 0; i < b.length; i++) {
            bytes1 char = b[i];

            // Uppercase A-Z → lowercase a-z
            if (char >= 0x41 && char <= 0x5A) {
                result[i] = bytes1(uint8(char) + 32);
            }
            // Allow lowercase a-z, digits 0-9, and hyphen
            else if ((char >= 0x61 && char <= 0x7A) || (char >= 0x30 && char <= 0x39) || char == 0x2D) {
                result[i] = char;
            } else {
                revert InvalidName(name);
            }
        }

        return string(result);
    }

    function _getRandomDigits(string memory name) internal returns (uint16) {
        nonce++;
        return
            uint16(
                uint256(
                    keccak256(abi.encodePacked(block.timestamp, block.number, name, msg.sender, gasleft(), nonce))
                ) % 10000
            );
    }

    function _uintToStr(uint256 _i) internal pure returns (string memory str) {
        if (_i == 0) return "0";
        uint256 j = _i;
        uint256 length;
        while (j != 0) {
            length++;
            j /= 10;
        }
        bytes memory bstr = new bytes(length);
        uint256 k = length;
        j = _i;
        while (j != 0) {
            bstr[--k] = bytes1(uint8(48 + (j % 10)));
            j /= 10;
        }
        str = string(bstr);
    }
}
