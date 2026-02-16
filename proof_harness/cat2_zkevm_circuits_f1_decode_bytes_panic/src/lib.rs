#[cfg(test)]
mod tests {
    use aggregator::decode_bytes;

    fn batch_decode_sanity_path(blob_bytes: &[u8]) -> Result<Vec<u8>, String> {
        decode_bytes(blob_bytes).map_err(|e| e.to_string())
    }

    #[test]
    fn f1_empty_blob_panics_instead_of_error() {
        let outcome = std::panic::catch_unwind(|| {
            let _ = batch_decode_sanity_path(&[]);
        });
        assert!(
            outcome.is_err(),
            "expected panic when blob_bytes is empty, got graceful return"
        );
    }

    #[test]
    fn f1_encoding_flag_without_payload_panics_instead_of_error() {
        let outcome = std::panic::catch_unwind(|| {
            let _ = batch_decode_sanity_path(&[1u8]);
        });
        assert!(
            outcome.is_err(),
            "expected panic when encoded blob has zero payload, got graceful return"
        );
    }

    #[test]
    fn control_unencoded_payload_succeeds() {
        let decoded = batch_decode_sanity_path(&[0u8, 0xAA, 0xBB]).expect("must decode");
        assert_eq!(decoded, vec![0xAA, 0xBB]);
    }
}