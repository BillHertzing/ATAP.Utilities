using System;
using System.Collections.Generic;
using ATAP.Utilities.Philote;
namespace ATAP.Utilities.GenerateProgram {
  public class GGenerateProgramResult : IGGenerateProgramResult {
    public GGenerateProgramResult(bool dBExtractionSuccess, bool buildSuccess, bool unitTestsSuccess, double unitTestsCoverage, string generatedSolutionFileDirectory, ICollection<IGAssemblyGroup> collectionOfAssembliesBuilt, bool packagingSuccess, bool deploymentSuccess) {
      DBExtractionSuccess = dBExtractionSuccess;
      BuildSuccess = buildSuccess;
      UnitTestsSuccess = unitTestsSuccess;
      UnitTestsCoverage = unitTestsCoverage;
      GeneratedSolutionFileDirectory = generatedSolutionFileDirectory;
      CollectionOfAssembliesBuilt = collectionOfAssembliesBuilt;
      PackagingSuccess = packagingSuccess;
      DeploymentSuccess = deploymentSuccess;
      Philote = new Philote<IGGenerateProgramResult>();
    }

    public bool DBExtractionSuccess { get; init; }
    public bool BuildSuccess { get; init; }
    public bool UnitTestsSuccess { get; init; }
    public double UnitTestsCoverage { get; init; }
    public string GeneratedSolutionFileDirectory { get; init; }
    public ICollection<IGAssemblyGroup> CollectionOfAssembliesBuilt { get; init; }
    public bool PackagingSuccess { get; init; }
    public bool DeploymentSuccess { get; init; }
    public IPhilote<IGGenerateProgramResult> Philote { get; init; }
  }
}
