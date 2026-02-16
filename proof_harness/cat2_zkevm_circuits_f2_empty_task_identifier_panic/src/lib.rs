#[derive(Clone, Debug, Default)]
struct ChunkInfoLike {
    public_input_hash_low_u64: u64,
}

#[derive(Clone, Debug, Default)]
struct ChunkProofV2Like {
    chunk_info: ChunkInfoLike,
}

#[derive(Clone, Debug, Default)]
struct BatchProofV2Like {
    batch_hash: String,
}

#[derive(Clone, Debug, Default)]
struct BatchProvingTaskLike {
    chunk_proofs: Vec<ChunkProofV2Like>,
}

impl BatchProvingTaskLike {
    // Bug-parity with prover/src/types.rs: uses last().unwrap() on chunk_proofs.
    fn identifier(&self) -> String {
        self.chunk_proofs
            .last()
            .unwrap()
            .chunk_info
            .public_input_hash_low_u64
            .to_string()
    }
}

#[derive(Clone, Debug, Default)]
struct BundleProvingTaskLike {
    batch_proofs: Vec<BatchProofV2Like>,
}

impl BundleProvingTaskLike {
    // Bug-parity with prover/src/types.rs: uses last().unwrap() on batch_proofs.
    fn identifier(&self) -> String {
        self.batch_proofs.last().unwrap().batch_hash.to_string()
    }
}

// Bug-parity with prover/src/aggregator/prover.rs name derivation.
fn derive_batch_name(task: &BatchProvingTaskLike, name: Option<&str>) -> String {
    name.map_or_else(|| task.identifier(), ToString::to_string)
}

// Bug-parity with prover/src/aggregator/prover.rs name derivation.
fn derive_bundle_name(task: &BundleProvingTaskLike, name: Option<&str>) -> String {
    name.map_or_else(|| task.identifier(), ToString::to_string)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn f2_empty_batch_task_panics_before_validation() {
        let empty_task = BatchProvingTaskLike::default();

        let outcome = std::panic::catch_unwind(|| {
            let _ = derive_batch_name(&empty_task, None);
        });
        assert!(
            outcome.is_err(),
            "expected panic when batch chunk_proofs is empty"
        );
    }

    #[test]
    fn f2_empty_bundle_task_panics_before_validation() {
        let empty_task = BundleProvingTaskLike::default();

        let outcome = std::panic::catch_unwind(|| {
            let _ = derive_bundle_name(&empty_task, None);
        });
        assert!(
            outcome.is_err(),
            "expected panic when bundle batch_proofs is empty"
        );
    }

    #[test]
    fn control_non_empty_tasks_compute_identifiers() {
        let batch_task = BatchProvingTaskLike {
            chunk_proofs: vec![ChunkProofV2Like {
                chunk_info: ChunkInfoLike {
                    public_input_hash_low_u64: 42,
                },
            }],
        };
        let bundle_task = BundleProvingTaskLike {
            batch_proofs: vec![BatchProofV2Like {
                batch_hash: "0xabc".to_string(),
            }],
        };

        assert_eq!(derive_batch_name(&batch_task, None), "42");
        assert_eq!(derive_bundle_name(&bundle_task, None), "0xabc");
    }
}
