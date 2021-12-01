using System;
using System.Collections.Generic;
using ATAP.Utilities.StronglyTypedId;
namespace ATAP.Utilities.GenerateProgram {

  public record GGenerateProgramResultId<TValue> : AbstractStronglyTypedId<TValue>, IGGenerateProgramResultId<TValue> where TValue : notnull {}
  public class GGenerateProgramResult<TValue> : IGGenerateProgramResult<TValue> where TValue : notnull {
    public GGenerateProgramResult(bool dBExtractionSuccess, bool buildSuccess, bool unitTestsSuccess, double unitTestsCoverage, string generatedSolutionFileDirectory, IDictionary<IGAssemblyGroupId<TValue>, IGAssemblyGroup<TValue>> collectionOfAssembliesBuilt, bool packagingSuccess, bool deploymentSuccess) {
      DBExtractionSuccess = dBExtractionSuccess;
      BuildSuccess = buildSuccess;
      UnitTestsSuccess = unitTestsSuccess;
      UnitTestsCoverage = unitTestsCoverage;
      GeneratedSolutionFileDirectory = generatedSolutionFileDirectory;
      CollectionOfAssembliesBuilt = collectionOfAssembliesBuilt;
      PackagingSuccess = packagingSuccess;
      DeploymentSuccess = deploymentSuccess;
      Id = new GGenerateProgramResultId<TValue>();
    }

    public bool DBExtractionSuccess { get; init; }
    public bool BuildSuccess { get; init; }
    public bool UnitTestsSuccess { get; init; }
    public double UnitTestsCoverage { get; init; }
    public string GeneratedSolutionFileDirectory { get; init; }
    public IDictionary<IGAssemblyGroupId<TValue>, IGAssemblyGroup<TValue>> CollectionOfAssembliesBuilt { get; init; }
    public bool PackagingSuccess { get; init; }
    public bool DeploymentSuccess { get; init; }
    public  IGGenerateProgramResultId Id { get; init; }
  }
}







