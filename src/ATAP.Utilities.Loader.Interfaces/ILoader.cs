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

  // public interface IDynamicShimNameAndNamespace {
  //   string DynamicShimName { get; }
  //   string DynamicShimNamespace { get; }
  // }

  // public interface IDynamicTypeToShimDictionary {
  //   IDictionary<Type, IEnumerable<IDynamicShimNameAndNamespace>> DynamicTypeToShimCollection { get; }
  // }
  public interface ISubModulesInfo{

    Glob Glob { get; }
    Action<Type, object> Function { get; }

    Predicate<Type> Pred { get; }
  }
///
  public interface ILoadSubModules {
    IDictionary<Type, ISubModulesInfo> GetSubModulesInfo();
  }

  // public interface ILoaderAbstract<IType> {
  //   IType Load(IDynamicShimNameAndNamespace dynamicShimNameAndNamespace);
  //   void Configure();
  //   void Configure(ILoaderOptions options);
  // }

  // public abstract class LoaderAbstract<IType> : ILoaderAbstract<IType> {
  //   public abstract IType Load(IDynamicShimNameAndNamespace dynamicShimNameAndNamespace);
  //   public abstract IType Load(Glob shimGlob, Predicate<Type> pred);
  //   public abstract void Configure();
  //   public abstract void Configure(ILoaderOptions options);
  // }

}
