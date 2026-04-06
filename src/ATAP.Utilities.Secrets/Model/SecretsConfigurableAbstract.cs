using Microsoft.Extensions.Configuration;

namespace ATAP.Utilities.Secrets;

public abstract class SecretsConfigurableAbstract : SecretsAbstract, ISecretsConfigurableAbstract
{
  public IConfigurationRoot? ConfigurationRoot { get; set; }
}
