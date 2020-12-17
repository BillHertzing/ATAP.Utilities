using System.Collections.Generic;
namespace ATAP.Utilities.GenerateProgram {
  public interface IGGenerateProgramResult {
    public bool DBExtractionSuccess { get; init; }
    public bool BuildSuccess { get; init; }
    public bool UnitTestsSuccess { get; init; }
    public double UnitTestsCoverage { get; init; }
    public string GeneratedSolutionFileDirectory { get; init; }
    public ICollection<IGAssemblyGroup> CollectionOfAssembliesBuilt { get; init; }
    public bool PackagingSuccess { get; init; }
    public bool DeploymentSuccess { get; init; }

}
}
