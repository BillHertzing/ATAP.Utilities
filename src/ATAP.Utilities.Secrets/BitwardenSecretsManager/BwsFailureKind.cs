namespace ATAP.Utilities.Secrets.BitwardenSecretsManager;

public enum BwsFailureKind
{
  InvalidConfiguration,
  UnsupportedPlatform,
  TokenFolderMissing,
  TokenFileMissing,
  TokenPathInaccessible,
  TokenIdentityMismatch,
  TokenCiphertextCorrupt,
  TokenFormatUnsupported,
  TokenCandidateAmbiguous,
  ParentEnvironmentForbidden,
  CliNotFound,
  CliUntrusted,
  CliNonzeroExit,
  CliTimeout,
  CliCancelled,
  CliOutputTooLarge,
  CliJsonInvalid,
  SecretMissing,
  SecretDuplicate,
  SecretFieldMissing,
}
