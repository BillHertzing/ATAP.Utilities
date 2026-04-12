namespace ATAP.Utilities.Secrets;

public enum SecretsProviderKind
{
  BitwardenPasswordManager,
  BitwardenSecretsManager,
  AzureKeyVault,
  HashiCorpVault,
  KeePass,
  EnvironmentVariable,
  Custom
}
