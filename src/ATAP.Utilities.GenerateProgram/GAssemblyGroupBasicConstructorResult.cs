namespace ATAP.Utilities.GenerateProgram {
  public class GAssemblyGroupBasicConstructorResult : IGAssemblyGroupBasicConstructorResult {

    public string subDirectoryForGeneratedFiles { get; set; }
    public string baseNamespaceName { get; set; }
    public string gAssemblyGroupName { get; set; }
    public string gTitularAssemblyUnitName { get; set; }
    public string gTitularBaseCompilationUnitName { get; set; }
    public IGAssemblyGroup gAssemblyGroup { get; set; }
    public IGPatternReplacement gAssemblyGroupPatternReplacement { get; set; }
    public IGAssemblyUnit gTitularAssemblyUnit { get; set; }
    public IGPatternReplacement gTitularAssemblyUnitPatternReplacement { get; set; }
    public IGCompilationUnit gTitularDerivedCompilationUnit { get; set; }
    public IGPatternReplacement gTitularDerivedCompilationUnitPatternReplacement { get; set; }
    public IGCompilationUnit gTitularBaseCompilationUnit { get; set; }
    public IGPatternReplacement gTitularBaseCompilationUnitPatternReplacement { get; set; }
    public IGNamespace gNamespaceBase { get; set; }
    public IGNamespace gNamespaceDerived { get; set; }
    public IGClass gClassBase { get; set; }
    public IGClass gClassDerived { get; set; }
    public IGMethod gPrimaryConstructorBase { get; set; }
    public IGAssemblyUnit gTitularInterfaceAssemblyUnit { get; set; }
    public IGCompilationUnit gTitularInterfaceDerivedCompilationUnit { get; set; }
    public IGCompilationUnit gTitularInterfaceBaseCompilationUnit { get; set; }
    public IGInterface gTitularInterfaceDerivedInterface { get; set; }
    public IGInterface gTitularInterfaceBaseInterface { get; set; }

  }
}
