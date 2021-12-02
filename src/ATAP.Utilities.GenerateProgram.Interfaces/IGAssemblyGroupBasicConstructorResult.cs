using ATAP.Utilities.StronglyTypedId;

namespace ATAP.Utilities.GenerateProgram {
    public interface IGAssemblyGroupBasicConstructorResultId<TValue> : IAbstractStronglyTypedId<TValue> where TValue : notnull {}
  public interface IGAssemblyGroupBasicConstructorResult<TValue> where TValue : notnull {

    string SubDirectoryForGeneratedFiles { get; set; }
    string BaseNamespaceName { get; set; }
    string GAssemblyGroupName { get; set; }
    string GTitularAssemblyUnitName { get; set; }
    string GTitularBaseCompilationUnitName { get; set; }
    IGAssemblyGroup<TValue> GAssemblyGroup { get; set; }
    IGPatternReplacement<TValue> gAssemblyGroupPatternReplacement { get; set; }
    IGAssemblyUnit<TValue> GTitularAssemblyUnit { get; set; }
    IGPatternReplacement<TValue> GTitularAssemblyUnitPatternReplacement { get; set; }
    IGCompilationUnit<TValue> GTitularDerivedCompilationUnit { get; set; }
    IGPatternReplacement<TValue> GTitularDerivedCompilationUnitPatternReplacement { get; set; }
    IGCompilationUnit<TValue> GTitularBaseCompilationUnit { get; set; }
    IGPatternReplacement<TValue> GTitularBaseCompilationUnitPatternReplacement { get; set; }
    IGNamespace<TValue> GNamespaceBase { get; set; }
    IGNamespace<TValue> GNamespaceDerived { get; set; }
    IGClass<TValue> GClassBase { get; set; }
    IGClass<TValue> GClassDerived { get; set; }
    IGMethod<TValue> GPrimaryConstructorBase { get; set; }
    IGAssemblyUnit<TValue> gTitularInterfaceAssemblyUnit { get; set; }
    IGCompilationUnit<TValue> GTitularInterfaceDerivedCompilationUnit { get; set; }
    IGCompilationUnit<TValue> GTitularInterfaceBaseCompilationUnit { get; set; }
    IGInterface<TValue> GTitularInterfaceDerivedInterface { get; set; }
    IGInterface<TValue> GTitularInterfaceBaseInterface { get; set; }

    IGAssemblyGroupBasicConstructorResultId<TValue> Id { get; init; }

  }
}


