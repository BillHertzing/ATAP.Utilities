using System;
using System.Collections;
using System.Collections.Generic;

namespace ATAP.Utilities.Loader {
  public interface ILoaderShimNameAndNamespaceConfigurationRootKeyAndDefaultValue {
    string LoaderShimNameConfigurationRootKey { get; init; }
    string LoaderShimNameConfigurationDefault { get; init; }
    string LoaderShimNamespaceConfigurationRootKey { get; init; }
    string LoaderShimNamespaceConfigurationDefault { get; init; }
  }

  public interface ILoaderShimNameAndNamespace {
    string LoaderShimName { get; init; }
    string LoaderShimNamespace { get; init; }
  }

  public interface ILoader<IType> {
    IType Load(object obj);
    void LoadDynamicSubModules(string loaderShimName, string loaderShimNamespace);
    void Configure();
    void Configure(ILoaderOptions options);
  }
}
