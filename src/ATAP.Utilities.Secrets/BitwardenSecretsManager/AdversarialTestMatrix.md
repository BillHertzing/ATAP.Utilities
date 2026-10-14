# Bitwarden Secrets Manager adversarial test matrix

This matrix closes Task 15.152.d at build-state only. It maps every board-listed
close variant to the Task 15.150.e threat review and deliberately separates
deterministic local evidence from assertions that require a target Windows host.
No row makes a live-service, ACL, profile, filesystem-filter, package, feed, or
deployment claim.

## Close-variant coverage

| Board-listed variant | Threat IDs | Verified local behavior | Target-host assertion or residual assumption | Owner and downstream gate |
| --- | --- | --- | --- | --- |
| Case-variant and substring SecretNames | O150E-T03, O150E-T21 | `AdversarialCloseVariantTests.GetSecretAsync_CaseAndSubstringNeighborsCannotReplaceExactSecretName` proves ordinal exact selection and typed `SecretMissing` for case and substring neighbors. | Vault-side project grants and SecretName metadata policy are not inferred from unit output. | Task 15.154 owns metadata-only grant inventory; B10 and Task 15.155 gate deploy-state acceptance. |
| Duplicate keys across granted projects | O150E-T02, O150E-T03, O150E-T21 | `AdversarialCloseVariantTests.GetSecretAsync_DuplicateNameAcrossVisibleProjectsFailsClosed` proves a configured-project match plus the same key from a foreign project rejects the complete response as `CliJsonInvalid` without value disclosure. | The actual `bws secret list` schema and visibility across grants require fixture pinning; unit output does not prove vault grants. | Task 15.154 owns project-grant inventory; Task 15.155 owns deployed graph and two-identity proof. |
| JSON scalar, object, null, and array values | O150E-T07, O150E-T21 | `AdversarialCloseVariantTests.GetSecretAsync_JsonScalarObjectNullAndArrayFieldsHaveDeterministicProjection` proves scalar/object/null/array field projection; Wave 2 separately proves strict root scalar/null rejection. | Actual `bws` schema/version behavior remains fixture-pinned without live values. | Task 15.152.e documents the supported schema; Task 15.155 gates deployed CLI-version compatibility. |
| Oversized output | O150E-T07, O150E-T19, O150E-T21 | `ConcurrentAndReplacementRaceTests.RunAsync_OversizedOutputFailsWithTypedBoundedResult` proves both streams are drained, capture is bounded, output is suppressed, and `CliOutputTooLarge` is returned. | Target process accounting and operating-system pipe behavior are not generalized from one test host. | Task 15.154 owns executable/host evidence under B09; Task 15.155 owns deployment verification. |
| Hung child | O150E-T05, O150E-T19 | `ConcurrentAndReplacementRaceTests.RunAsync_HungChildTimesOutAndTerminatesItsProcessTree` proves bounded timeout and observed child/descendant exit. | Complete Windows descendant termination in every process-generation race remains an explicit Task 15.150.e assertion. | Task 15.154 owns target-host process-tree evidence; Task 15.155 gates deploy-state acceptance. |
| Timeout/cancellation race | O150E-T05, O150E-T19 | Ordered race tests prove cancellation-first yields `CliCancelled`, deadline-first yields `CliTimeout`, and both observed trees exit. Whichever signal is first is the durable local assumption; simultaneous scheduling order is intentionally unspecified. | Windows job-object choice and exact simultaneous-signal ordering are not claimed. | Task 15.154 owns process-lifecycle prototype evidence; Task 15.155 owns final residual-risk disposition. |
| Concurrent callers | O150E-T05, O150E-T07, O150E-T19 | `ConcurrentAndReplacementRaceTests.RunAsync_ConcurrentCallersRemainIndependentAndSecretSafe` proves six callers complete with independent outputs, child-only token placement, no parent token, and no returned token canary. | This is not a load, quota, or service-availability claim. | Task 15.153 owns application concurrency/startup behavior; Task 15.155 owns deployed load and monitoring gates. |
| Token-file replacement during read | O150E-T01, O150E-T15, O150E-T16 | `ConcurrentAndReplacementRaceTests.AcquireAsync_ReplacementAfterPathValidationFailsClosed` deterministically replaces the candidate after path validation and proves unsupported replacement content fails before decryption. | One-opened-handle identity, atomic replacement, antivirus/filter delay, and valid-ciphertext replacement are unverified; current validation-to-reopen behavior is not accepted as target-volume proof. | Task 15.154 owns blocker B08 target-volume replace/crash/ACL evidence; Task 15.155 gates deployment. |
| Service-account profile absence | O150E-T04, O150E-T12, O150E-T22 | `AdversarialCloseVariantTests.AcquireAsync_AbsentServiceAccountProfileAndTokenSlotFailsClosed` uses a synthetic service identity with no profile/token root and proves `TokenFolderMissing` before decryption. | Actual service SID, profile loading, startup ordering, certificate store, and service-control outcome require a target host. | Ace Task 15.153.c/d owns host startup tests; Task 15.154 owns B03/B06 service-profile evidence; Task 15.155 gates deployment. |

## Durable assumptions and stop boundaries

- These tests use only synthetic values, fake process output, fake identity and
  path-security boundaries, current test-host process APIs, and temporary paths.
- A local passing test is verified build-state behavior, not evidence that a
  service account has a loaded profile, correct ACLs, correct vault grants, or
  reliable atomic replacement on its deployment volume.
- The reader currently validates a path and then reopens it. The deterministic
  replacement test proves malformed replacement fails closed; it does not prove
  opened-handle identity or safe acceptance of every valid replacement. B08 and
  O150E-T16 therefore remain mandatory downstream gates.
- Timeout and cancellation classification is deterministic when their order is
  controlled. Exact simultaneous arrival has no promised precedence; both paths
  must remain typed, bounded, secret-safe, and terminal.
- Any real token/secret in evidence, orphaned child, accepted ambiguous candidate,
  or target-host claim inferred from these tests is a stop condition.

## Evidence owner

Task 15.152.d owns the local test/TRX evidence under
`_generated/Sprint0015/StreamO/Task15.152/15.152.d/`. Tasks 15.153-15.155 own
the application-host, provisioning, and deploy-state gates named above.
