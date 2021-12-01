namespace ATAP.Utilities.GenerateProgram {
  public class GAssemblyGroupBasicConstructorResult : IGAssemblyGroupBasicConstructorResult {

    public string SubDirectoryForGeneratedFiles { get; set; }
    public string BaseNamespaceName { get; set; }
    public string GAssemblyGroupName { get; set; }
    public string GTitularAssemblyUnitName { get; set; }
    public string GTitularBaseCompilationUnitName { get; set; }
    public IGAssemblyGroup GAssemblyGroup { get; set; }
    public IGPatternReplacement gAssemblyGroupPatternReplacement { get; set; }
    public IGAssemblyUnit GTitularAssemblyUnit { get; set; }
    public IGPatternReplacement GTitularAssemblyUnitPatternReplacement { get; set; }
    public IGCompilationUnit GTitularDerivedCompilationUnit { get; set; }
    public IGPatternReplacement GTitularDerivedCompilationUnitPatternReplacement { get; set; }
    public IGCompilationUnit GTitularBaseCompilationUnit { get; set; }
    public IGPatternReplacement GTitularBaseCompilationUnitPatternReplacement { get; set; }
    public IGNamespace GNamespaceBase { get; set; }
    public IGNamespace GNamespaceDerived { get; set; }
    public IGClass GClassBase { get; set; }
    public IGClass GClassDerived { get; set; }
    public IGMethod GPrimaryConstructorBase { get; set; }
    public IGAssemblyUnit gTitularInterfaceAssemblyUnit { get; set; }
    public IGCompilationUnit GTitularInterfaceDerivedCompilationUnit { get; set; }
    public IGCompilationUnit GTitularInterfaceBaseCompilationUnit { get; set; }
    public IGInterface GTitularInterfaceDerivedInterface { get; set; }
    public IGInterface GTitularInterfaceBaseInterface { get; set; }

  }
}






