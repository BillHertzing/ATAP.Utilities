using System;
using System.Collections.Generic;
using ATAP.Utilities.Philote;
namespace ATAP.Utilities.GenerateProgram {
  public record GGenerateProgramResult : IGGenerateProgramResult {
    public GGenerateProgramResult(bool dBExtractionSuccess, bool buildSuccess, bool unitTestsSuccess, double unitTestsCoverage, string generatedSolutionFileDirectory, ICollection<GAssemblyGroup> collectionOfAssembliesBuilt, bool packagingSuccess, bool deploymentSuccess) {
      DBExtractionSuccess = dBExtractionSuccess;
      BuildSuccess = buildSuccess;
      UnitTestsSuccess = unitTestsSuccess;
      UnitTestsCoverage = unitTestsCoverage;
      GeneratedSolutionFileDirectory = generatedSolutionFileDirectory;
      CollectionOfAssembliesBuilt = collectionOfAssembliesBuilt;
      PackagingSuccess = packagingSuccess;
      DeploymentSuccess = deploymentSuccess;
      Philote = new Philote<GGenerateProgramResult>();

    }

    public bool DBExtractionSuccess { get; }
    public bool BuildSuccess { get; }
    public bool UnitTestsSuccess { get; }
    public double UnitTestsCoverage { get; }
    public string GeneratedSolutionFileDirectory { get; }
    public ICollection<GAssemblyGroup> CollectionOfAssembliesBuilt { get; }
    public bool PackagingSuccess { get; }
    public bool DeploymentSuccess { get; }
    public Philote<GGenerateProgramResult> Philote { get; }
  }
}
