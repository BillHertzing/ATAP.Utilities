namespace ATAP.Utilities.Secrets;

using System.Collections.Generic;
using Microsoft.Extensions.Configuration;

public class BitwardenConfigurationSource : IConfigurationSource
{
  private readonly BitwardenSecretsOptions _options;
  private readonly IEnumerable<SecretMapping> _mappings;

  public BitwardenConfigurationSource(BitwardenSecretsOptions options, IEnumerable<SecretMapping> mappings)
  {
    _options = options;
    _mappings = mappings;
  }

  public IConfigurationProvider Build(IConfigurationBuilder builder) =>
      new BitwardenConfigurationProvider(_options, _mappings);
}
