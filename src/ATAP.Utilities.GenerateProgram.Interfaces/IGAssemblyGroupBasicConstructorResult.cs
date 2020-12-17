namespace ATAP.Utilities.GenerateProgram {
  public interface IGAssemblyGroupBasicConstructorResult {
    string subDirectoryForGeneratedFiles { get; set; }
    string baseNamespaceName { get; set; }
    string gAssemblyGroupName { get; set; }
    string gTitularAssemblyUnitName { get; set; }
    string gTitularBaseCompilationUnitName { get; set; }
    IGAssemblyGroup gAssemblyGroup { get; set; }
    IGPatternReplacement gAssemblyGroupPatternReplacement { get; set; }
    IGAssemblyUnit gTitularAssemblyUnit { get; set; }
    IGPatternReplacement gTitularAssemblyUnitPatternReplacement { get; set; }
    IGCompilationUnit gTitularDerivedCompilationUnit { get; set; }
    IGPatternReplacement gTitularDerivedCompilationUnitPatternReplacement { get; set; }
    IGCompilationUnit gTitularBaseCompilationUnit { get; set; }
    IGPatternReplacement gTitularBaseCompilationUnitPatternReplacement { get; set; }
    IGNamespace gNamespaceBase { get; set; }
    IGNamespace gNamespaceDerived { get; set; }
    IGClass gClassBase { get; set; }
    IGClass gClassDerived { get; set; }
    IGMethod gPrimaryConstructorBase { get; set; }
    IGAssemblyUnit gTitularInterfaceAssemblyUnit { get; set; }
    IGCompilationUnit gTitularInterfaceDerivedCompilationUnit { get; set; }
    IGCompilationUnit gTitularInterfaceBaseCompilationUnit { get; set; }
    IGInterface gTitularInterfaceDerivedInterface { get; set; }
    IGInterface gTitularInterfaceBaseInterface { get; set; }
  }
}
