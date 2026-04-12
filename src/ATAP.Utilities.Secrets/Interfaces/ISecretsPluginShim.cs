using System.Collections.Generic;
using Microsoft.Extensions.Configuration;
using ATAP.Utilities.Plugin;

namespace ATAP.Utilities.Secrets;

public interface ISecretsPluginShim : IPluginShim<ISecretsAbstract>
{
  IConfigurationSource CreateConfigurationSource(IEnumerable<SecretMapping> mappings);
}
