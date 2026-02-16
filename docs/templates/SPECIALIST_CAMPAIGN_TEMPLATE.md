# Specialist Campaign Template (EVM)

## Campaign Info

- Finding ID: `<fX>`
- Repo: `<repo>`
- Harness dir: `<path>`
- Harness source: `<path>`
- Harness contract: `<name>`
- Property target: `<property_*>`
- Timestamp (UTC): `<yyyy-mm-dd hh:mm:ss UTC>`

## Commands

- Medusa:
- `<command>`

- Echidna:
- `<command>`

## Parameters

- seq-len: `<int>`
- workers: `<int>`
- timeout-sec: `<int>`
- echidna test-limit: `<int>`

## Results

- Medusa exit code: `<int>`
- Echidna exit code: `<int>`
- Property falsified: `<yes|no>`
- Minimized sequence length: `<int>`

## Artifacts

- Medusa output: `<path>`
- Echidna output: `<path>`
- Metadata JSON: `<path>`

## Notes

- Non-zero exit is expected when a property is falsified.
- Include the exact minimized sequence in the finding section.

