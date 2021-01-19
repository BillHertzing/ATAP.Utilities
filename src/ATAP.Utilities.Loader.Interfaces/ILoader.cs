using System;
using System.Collections;
using System.Collections.Generic;
using System.Reflection;
using System.Runtime.Loader;
using ATAP.Utilities.FileIO;

namespace ATAP.Utilities.Loader {
  public interface IDynamicGlobAndPredicate {
    Glob Glob {get;}
    Predicate<Type> Predicate {get;}
  }


  public interface IDynamicShimNameAndNamespaceConfigRootKeyAndDefaultValue {
    string DynamicShimNameConfigRootKey { get; }
    string DynamicShimNameConfigDefault { get; }
    string DynamicShimNamespaceConfigRootKey { get; }
    string DynamicShimNamespaceConfigurationDefault { get; }
  }

  public interface IDynamicShimNameAndNamespace {
    string DynamicShimName { get; }
    string DynamicShimNamespace { get; }
  }

  public interface IDynamicTypeToShimDictionary {
    IDictionary<Type, IEnumerable<IDynamicShimNameAndNamespace>> DynamicTypeToShimCollection { get; }
  }
  public interface ISubModulesInfo<Type> {
    Action<object> Function {get;}
    Predicate<IEnumerable<ILoaderAbstract<Type>>> Pred {get;}
  }

  public interface ILoadSubModules {
    IDictionary<Type, ISubModulesInfo<Type>> GetSubModulesInfo();
    /// uses list of types and dynamicShimNameAndNamespaceCollection built in to the dynamically loaded instance
    /// searches from the directory from which the dynamic shim module was loaded, downward
    void LoadSubModules();
    // as above, allows additional probingPaths before the default ones
    void LoadSubModules(string[] relativePathsToProbe = default);
    // as above, allows specifing one type and a collection of shim constraints that seek to identify a dynamic module to fulfill it
    void LoadSubModules(Type type, IEnumerable<IDynamicShimNameAndNamespace> dynamicShimNameAndNamespaceCollection, string[] relativePathsToProbe);
    // as above, allows specifing a dictionary of types and corresponding collections of shim constraints,
    // so that multiple types can be dynamically loaded
    void LoadSubModules(IDynamicTypeToShimDictionary DynamicTypeToShimDictionary, string[] relativePathsToProbe);
  }
  public interface ILoaderAbstract<IType> {
    IType Load(IDynamicShimNameAndNamespace dynamicShimNameAndNamespace);
    void Configure();
    void Configure(ILoaderOptions options);
  }

  public abstract class LoaderAbstract<IType> : ILoaderAbstract<IType> {
    public abstract IType Load(IDynamicShimNameAndNamespace dynamicShimNameAndNamespace);
    public abstract IType Load(Glob shimGlob, Predicate<Type> pred);
    public abstract void Configure();
    public abstract void Configure(ILoaderOptions options);
  }

}
