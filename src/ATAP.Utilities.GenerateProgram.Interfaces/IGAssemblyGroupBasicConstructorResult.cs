namespace ATAP.Utilities.GenerateProgram {
  public interface IGAssemblyGroupBasicConstructorResult {
    string SubDirectoryForGeneratedFiles { get; set; }
    string BaseNamespaceName { get; set; }
    string GAssemblyGroupName { get; set; }
    string GTitularAssemblyUnitName { get; set; }
    string GTitularBaseCompilationUnitName { get; set; }
    IGAssemblyGroup GAssemblyGroup { get; set; }
    IGPatternReplacement gAssemblyGroupPatternReplacement { get; set; }
    IGAssemblyUnit GTitularAssemblyUnit { get; set; }
    IGPatternReplacement GTitularAssemblyUnitPatternReplacement { get; set; }
    IGCompilationUnit GTitularDerivedCompilationUnit { get; set; }
    IGPatternReplacement GTitularDerivedCompilationUnitPatternReplacement { get; set; }
    IGCompilationUnit GTitularBaseCompilationUnit { get; set; }
    IGPatternReplacement GTitularBaseCompilationUnitPatternReplacement { get; set; }
    IGNamespace GNamespaceBase { get; set; }
    IGNamespace GNamespaceDerived { get; set; }
    IGClass GClassBase { get; set; }
    IGClass GClassDerived { get; set; }
    IGMethod GPrimaryConstructorBase { get; set; }
    IGAssemblyUnit gTitularInterfaceAssemblyUnit { get; set; }
    IGCompilationUnit GTitularInterfaceDerivedCompilationUnit { get; set; }
    IGCompilationUnit GTitularInterfaceBaseCompilationUnit { get; set; }
    IGInterface GTitularInterfaceDerivedInterface { get; set; }
    IGInterface GTitularInterfaceBaseInterface { get; set; }
  }
}


