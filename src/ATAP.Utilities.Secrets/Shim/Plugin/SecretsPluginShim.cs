namespace ATAP.Utilities.Secrets;

using System;
using System.Collections.Generic;
using ATAP.Utilities.Loader;
using ATAP.Utilities.Plugin;
using Microsoft.Extensions.DependencyInjection;

public class SecretsPluginShim : PluginShimBase<ISecretsAbstract>, ILoadDynamicSubModules
{
  private ISecretsAbstract? _loadedProvider;

  public override string PluginId => "atap.secrets.plugin";
  public override string DisplayName => "Secrets Plugin Loader";
  public override Version Version => GetType().Assembly.GetName().Version!;
  public override Type FamilyInterface => typeof(ISecretsAbstract);

  public override ISecretsAbstract GetService() =>
      _loadedProvider ?? throw new InvalidOperationException(
          $"No secrets provider has been loaded by {nameof(SecretsPluginShim)}.");

  public override void RegisterServices(IServiceCollection services)
  {
    if (_loadedProvider is not null)
      services.AddSingleton<ISecretsAbstract>(_loadedProvider);
  }

  public IDictionary<Type, IDynamicSubModulesInfo> GetDynamicSubModulesInfo()
  {
    return new Dictionary<Type, IDynamicSubModulesInfo>
    {
      [typeof(ISecretsAbstract)] = new DynamicSubModulesInfo
      {
        DynamicGlobAndPredicate = new DynamicGlobAndPredicate
        {
          Glob = new ATAP.Utilities.FileIO.Glob { Pattern = StringConstants.SecretsPluginGlobPattern },
          Predicate = type => typeof(ISecretsAbstract).IsAssignableFrom(type)
              && !type.IsAbstract
              && !type.IsInterface,
        },
        Function = instance =>
        {
          if (instance is ISecretsAbstract provider)
            _loadedProvider = provider;
        },
      }
    };
  }
}
