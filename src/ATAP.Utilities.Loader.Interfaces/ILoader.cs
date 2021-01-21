using System;
using System.Collections;
using System.Collections.Generic;
using System.Reflection;
using System.Runtime.Loader;

using ATAP.Utilities.FileIO;

namespace ATAP.Utilities.Loader {
  public interface IDynamicGlobAndPredicate {
    Glob Glob { get; }
    Predicate<Type> Predicate { get; }
  }

  public interface IDynamicShimNameAndNamespaceConfigRootKeyAndDefaultValue {
    string DynamicShimNameConfigRootKey { get; }
    string DynamicShimNameConfigDefault { get; }
    string DynamicShimNamespaceConfigRootKey { get; }
    string DynamicShimNamespaceConfigurationDefault { get; }
  }

  public interface IDynamicSubModulesInfo {
    IDynamicGlobAndPredicate DynamicGlobAndPredicate { get; }
    Action<object> Function { get; }
  }
///
  public interface ILoadDynamicSubModules {
    IDictionary<Type, IDynamicSubModulesInfo> GetDynamicSubModulesInfo();
  }

}
