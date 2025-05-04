// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

// Mock imports
import { ProfileHub } from "../contracts/ProfileHub.sol";
import { ProfileLink } from "../contracts/ProfileLink.sol";

// OApp imports
import { IOAppOptionsType3, EnforcedOptionParam } from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OAppOptionsType3.sol";
import { OptionsBuilder } from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OptionsBuilder.sol";
import { ONFT721 } from "@layerzerolabs/onft-evm/contracts/onft721/ONFT721.sol";
import { ONFT721Adapter } from "@layerzerolabs/onft-evm/contracts/onft721/ONFT721Adapter.sol";

// OFT imports
import { IONFT721, SendParam } from "@layerzerolabs/onft-evm/contracts/onft721/interfaces/IONFT721.sol";
import { MessagingFee, MessagingReceipt } from "@layerzerolabs/onft-evm/contracts/onft721/ONFT721Core.sol";
import { ONFT721MsgCodec } from "@layerzerolabs/onft-evm/contracts/onft721/libs/ONFT721MsgCodec.sol";
import { ONFTComposeMsgCodec } from "@layerzerolabs/onft-evm/contracts/libs/ONFTComposeMsgCodec.sol";

// Forge imports
import "forge-std/console.sol";

// DevTools imports
import { TestHelperOz5 } from "@layerzerolabs/test-devtools-evm-foundry/contracts/TestHelperOz5.sol";

contract ProfileTest is TestHelperOz5 {
    using OptionsBuilder for bytes;

    uint32 private aEid = 1;
    uint32 private bEid = 2;

    ProfileHub private profileHub;
    ProfileLink private profileLink;

    address private userA = address(0x1);
    address private userB = address(0x2);
    uint256 private initialBalance = 100 ether;

    function setUp() public virtual override {
        vm.deal(userA, 1000 ether);
        vm.deal(userB, 1000 ether);

        super.setUp();
        setUpEndpoints(2, LibraryType.UltraLightNode);

        profileHub = ProfileHub(
            _deployOApp(
                type(ProfileHub).creationCode,
                abi.encode("profileHub", "profileHub", address(endpoints[aEid]), address(this))
            )
        );

        profileLink = ProfileLink(
            _deployOApp(
                type(ProfileLink).creationCode,
                abi.encode("profileLink", "profileLink", address(endpoints[bEid]), address(this))
            )
        );

        // config and wire the onfts
        address[] memory onfts = new address[](2);
        onfts[0] = address(profileHub);
        onfts[1] = address(profileLink);
        this.wireOApps(onfts);

        // mint tokens
        profileHub.mint(userA);
    }

    function test_constructor() public view {
        assertEq(profileHub.owner(), address(this));
        assertEq(profileLink.owner(), address(this));

        assertEq(profileHub.balanceOf(userA), 1);
        assertEq(profileLink.balanceOf(userB), 0);

        assertEq(profileHub.token(), address(profileHub));
        assertEq(profileLink.token(), address(profileLink));
    }

    function test_send_profile() public {
        uint256 tokenId = 1;
        bytes memory options = OptionsBuilder.newOptions().addExecutorLzReceiveOption(200000, 0);
        SendParam memory sendParam = SendParam(bEid, addressToBytes32(userB), tokenId, options, "", "");
        MessagingFee memory fee = profileHub.quoteSend(sendParam, false);

        assertEq(profileHub.balanceOf(userA), 1);
        assertEq(profileLink.balanceOf(userB), 0);
        assertEq(profileHub.isFrozen(tokenId), false);

        vm.prank(userA);
        profileHub.send{ value: fee.nativeFee }(sendParam, fee, payable(address(this)));
        verifyPackets(bEid, addressToBytes32(address(profileLink)));

        assertEq(profileHub.balanceOf(userA), 1);
        assertEq(profileLink.balanceOf(userB), 1);
        assertEq(profileHub.isFrozen(tokenId), true);
    }

    function test_profile_freeze() public {
        uint256 tokenId = 1;
        bytes memory options = OptionsBuilder.newOptions().addExecutorLzReceiveOption(200000, 0);
        SendParam memory sendParam = SendParam(bEid, addressToBytes32(userB), tokenId, options, "", "");
        MessagingFee memory fee = profileHub.quoteSend(sendParam, false);

        assertEq(profileHub.isFrozen(tokenId), false);

        vm.prank(userA);
        profileHub.send{ value: fee.nativeFee }(sendParam, fee, payable(address(this)));
        verifyPackets(bEid, addressToBytes32(address(profileLink)));

        assertEq(profileHub.isFrozen(tokenId), true);

        vm.prank(userA);
        vm.expectRevert();
        profileHub.transferFrom(userA, userB, tokenId);
    }

    function test_receive_profile_on_hub() public {
        uint256 tokenId = 1;
        bytes memory options = OptionsBuilder.newOptions().addExecutorLzReceiveOption(200000, 0);
        SendParam memory sendParam = SendParam(bEid, addressToBytes32(userB), tokenId, options, "", "");
        MessagingFee memory fee = profileHub.quoteSend(sendParam, false);

        assertEq(profileHub.balanceOf(userA), 1);
        assertEq(profileLink.balanceOf(userB), 0);
        assertEq(profileHub.isFrozen(tokenId), false);

        vm.prank(userA);
        profileHub.send{ value: fee.nativeFee }(sendParam, fee, payable(address(this)));
        verifyPackets(bEid, addressToBytes32(address(profileLink)));

        assertEq(profileHub.balanceOf(userA), 0);
        assertEq(profileHub.balanceOf(userB), 1);
        assertEq(profileLink.balanceOf(userB), 1);
        assertEq(profileHub.isFrozen(tokenId), true);

        bytes memory optionsB = OptionsBuilder.newOptions().addExecutorLzReceiveOption(200000, 0);
        SendParam memory sendParamB = SendParam(aEid, addressToBytes32(userA), tokenId, optionsB, "", "");
        MessagingFee memory feeB = profileLink.quoteSend(sendParamB, false);

        vm.prank(userB);
        profileLink.send{ value: feeB.nativeFee }(sendParamB, feeB, payable(address(this)));
        verifyPackets(aEid, addressToBytes32(address(profileHub)));

        assertEq(profileHub.balanceOf(userA), 1);
        assertEq(profileHub.balanceOf(userB), 0);
        assertEq(profileLink.balanceOf(userB), 0);
        assertEq(profileHub.isFrozen(tokenId), false);
    }
}
