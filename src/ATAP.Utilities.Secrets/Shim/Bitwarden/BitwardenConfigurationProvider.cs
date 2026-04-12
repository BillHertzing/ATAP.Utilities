namespace ATAP.Utilities.Secrets;

using System;
using System.Collections.Generic;
using System.Threading;
using System.Threading.Tasks;
using Microsoft.Extensions.Configuration;

internal class BitwardenConfigurationProvider : ConfigurationProvider
{
  private readonly BitwardenSecretsShim _shim;
  private readonly IEnumerable<SecretMapping> _mappings;

  public BitwardenConfigurationProvider(BitwardenSecretsOptions options, IEnumerable<SecretMapping> mappings)
  {
    _shim = new BitwardenSecretsShim(options);
    _mappings = mappings;
  }

  public override void Load()
  {
    if (!_shim.IsAvailable()) return;

    var data = new Dictionary<string, string?>(StringComparer.OrdinalIgnoreCase);
    foreach (var m in _mappings)
    {
      var value = _shim.GetSecretAsync(m.SecretName, m.FieldName).GetAwaiter().GetResult();
      if (value is not null)
        data[m.ConfigurationKey] = value;
    }
    Data = data!;
  }
}
