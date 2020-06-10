namespace GenerateProgram {
  public class MCreateAssemblyGroupResult {

    public string subDirectoryForGeneratedFiles { get; set; }
      public string baseNamespaceName { get; set; }
      public string gAssemblyGroupName { get; set; }
      public string gTitularAssemblyUnitName { get; set; }
      public string gTitularBaseCompilationUnitName { get; set; }
      public GAssemblyGroup gAssemblyGroup { get; set; }
      public GPatternReplacement gAssemblyGroupPatternReplacement { get; set; }
      public GAssemblyUnit gTitularAssemblyUnit { get; set; }
      public GPatternReplacement gTitularAssemblyUnitPatternReplacement { get; set; }
      public GCompilationUnit gTitularDerivedCompilationUnit { get; set; }
      public GPatternReplacement gTitularDerivedCompilationUnitPatternReplacement { get; set; }
      public GCompilationUnit gTitularBaseCompilationUnit { get; set; }
      public GPatternReplacement gTitularBaseCompilationUnitPatternReplacement { get; set; }
      public GNamespace gNamespaceBase { get; set; }
      public GNamespace gNamespaceDerived { get; set; }
      public GClass gClassBase { get; set; }
      public GClass gClassDerived { get; set; }
      public GMethod gPrimaryConstructorBase { get; set; }
      public GAssemblyUnit gTitularInterfaceAssemblyUnit { get; set; }
      public GCompilationUnit gTitularInterfaceDerivedCompilationUnit { get; set; }
      public GCompilationUnit gTitularInterfaceBaseCompilationUnit { get; set; }
      public GInterface gTitularInterfaceDerivedInterface { get; set; }
      public GInterface gTitularInterfaceBaseInterface { get; set; }

  }
}
