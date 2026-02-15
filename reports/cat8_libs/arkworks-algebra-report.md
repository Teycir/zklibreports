# Custom Vulnerability Report: arkworks-algebra

## Scope
- Audit time (UTC): 2026-02-15 18:09:20
- Repository path: \\VBOXSVR\elements\Repos\zk0d\cat_8_libs\arkworks-algebra
- Language profile: Rust
- Git branch: master
- Git commit: 598a5fb
- Upstream: origin/master
- Upstream delta: behind=0 ahead=0
- Remote: https://github.com/arkworks-rs/algebra.git

## Method
- Fast skimmer triage over executable paths (tests/docs excluded from pattern scans).
- Dependency advisory scan when lockfile/tooling was available.
- No issue is marked CONFIRMED unless reproducible witness evidence exists.

## Tooling Results
- cargo-audit skipped: Cargo.lock not present (library crate)

## Classification Summary
- FORMALLY CONFIRMED: 0
- CONFIRMED: 0
- LIKELY: 0
- NOT CONFIRMED (skimmer hints): 671 matches across 4 pattern classes

## Likely Findings
- None in this pass.

## Not Confirmed Notes
- None in this pass.

## Skimmer Hints (Not Confirmed)
### Security-related TODO or FIXME
- Match count: 1
- Sample evidence:
```text
\\VBOXSVR\elements\Repos\zk0d\cat_8_libs\arkworks-algebra\poly\src\domain\radix2\fft.rs:132:        // TODO: check if this method can replace parallel compute powers.
```

### Unsafe blocks
- Match count: 8
- Sample evidence:
```text
\\VBOXSVR\elements\Repos\zk0d\cat_8_libs\arkworks-algebra\ff\src\fields\models\fp\montgomery_backend.rs:211:                    _ => unsafe { ark_std::hint::unreachable_unchecked() },
\\VBOXSVR\elements\Repos\zk0d\cat_8_libs\arkworks-algebra\ff\src\fields\models\fp\montgomery_backend.rs:273:                _ => unsafe { ark_std::hint::unreachable_unchecked() },
\\VBOXSVR\elements\Repos\zk0d\cat_8_libs\arkworks-algebra\ff\src\const_helpers.rs:126:        unsafe { ark_std::slice::from_raw_parts((self as *const Self) as *const u8, 8 * N + 1) }
\\VBOXSVR\elements\Repos\zk0d\cat_8_libs\arkworks-algebra\ff\src\biginteger\mod.rs:366:                unsafe {
\\VBOXSVR\elements\Repos\zk0d\cat_8_libs\arkworks-algebra\ff\src\biginteger\arithmetic.rs:18:    unsafe {
\\VBOXSVR\elements\Repos\zk0d\cat_8_libs\arkworks-algebra\ff\src\biginteger\arithmetic.rs:52:    unsafe {
```

### Raw pointer or transmute usage
- Match count: 4
- Sample evidence:
```text
\\VBOXSVR\elements\Repos\zk0d\cat_8_libs\arkworks-algebra\Cargo.toml:57:borrow_as_ptr = "warn"
\\VBOXSVR\elements\Repos\zk0d\cat_8_libs\arkworks-algebra\Cargo.toml:107:transmute_undefined_repr = "warn"
\\VBOXSVR\elements\Repos\zk0d\cat_8_libs\arkworks-algebra\Cargo.toml:125:as_ptr_cast_mut = "allow"
\\VBOXSVR\elements\Repos\zk0d\cat_8_libs\arkworks-algebra\ff\src\const_helpers.rs:126:        unsafe { ark_std::slice::from_raw_parts((self as *const Self) as *const u8, 8 * N + 1) }
```

### panic/unwrap/expect usage
- Match count: 658
- Sample evidence:
```text
\\VBOXSVR\elements\Repos\zk0d\cat_8_libs\arkworks-algebra\bench-templates\src\macros\field.rs:132:                    field_elements_left[i].inverse().unwrap()
\\VBOXSVR\elements\Repos\zk0d\cat_8_libs\arkworks-algebra\bench-templates\src\macros\field.rs:173:                    a.serialize_compressed(&mut bytes).unwrap();
\\VBOXSVR\elements\Repos\zk0d\cat_8_libs\arkworks-algebra\bench-templates\src\macros\field.rs:182:                    a.serialize_uncompressed(&mut bytes).unwrap();
\\VBOXSVR\elements\Repos\zk0d\cat_8_libs\arkworks-algebra\bench-templates\src\macros\field.rs:194:                    f[i].serialize_compressed(&mut bytes).unwrap()
\\VBOXSVR\elements\Repos\zk0d\cat_8_libs\arkworks-algebra\bench-templates\src\macros\field.rs:202:                    f[i].serialize_uncompressed(&mut bytes).unwrap()
\\VBOXSVR\elements\Repos\zk0d\cat_8_libs\arkworks-algebra\bench-templates\src\macros\field.rs:210:                    <$F>::deserialize_compressed(f_compressed[i].as_slice()).unwrap()
```

## Reproduction Commands
- rg -n -S --hidden --glob !**/.git/** -- <PATTERN> \\VBOXSVR\elements\Repos\zk0d\cat_8_libs\arkworks-algebra

## External Tool Deep Scan (2026-02-15 20:36 UTC)

### Tooling Results
- gitleaks: 0 findings.
- cargo deny advisories: errors=1 (`unmaintained`), warnings=0.
- cargo audit: vulnerabilities=0, unmaintained=1, unsound=0, yanked=0.
- Advisory IDs: `RUSTSEC-2024-0436` (`paste@1.0.15`).

### Deep Assessment
- [NOT CONFIRMED] The `paste` advisory is unmaintained/deprecation risk. No direct exploitable vulnerability advisory was produced in this pass.

### Artifacts
- `C:\Users\vboxuser\Desktop\Repos\zklibreports\artifacts\cargo-deny\arkworks-algebra.txt`
- `C:\Users\vboxuser\Desktop\Repos\zklibreports\artifacts\cargo-audit\arkworks-algebra.json`
- `C:\Users\vboxuser\Desktop\Repos\zklibreports\artifacts\gitleaks\arkworks-algebra.json`
