using Microsoft.Extensions.Configuration;

namespace ATAP.Utilities.Secrets;

public interface ISecretsConfigurableAbstract : ISecretsAbstract
{
  IConfigurationRoot? ConfigurationRoot { get; set; }
}
