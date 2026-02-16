# LayerZero-v2 full-source parity harness

This harness replays LayerZero findings directly against copied upstream source trees:

- `src/external/lz-evm-oapp-contracts`
- `src/external/lz-evm-protocol-v2`

Validated parity tests:

- `H1` OFTAdapter inbound-fee collateral collapse parity.
- `H2` stale delegate persistence parity after ownership transfer.

## Commands

From this directory:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File ..\..\scripts\forge.ps1 test -vv --match-test test_h1_full_source_parity_oft_adapter_inbound_fee_collapse
powershell -NoProfile -ExecutionPolicy Bypass -File ..\..\scripts\forge.ps1 test -vv --match-test test_h2_full_source_parity_stale_delegate_persists_post_transfer
```

