using System.Collections.Generic;
namespace ATAP.Utilities.GenerateProgram {
  public interface IGGenerateProgramResult {
    public bool DBExtractionSuccess { get; }
    public bool BuildSuccess { get; }
    public bool UnitTestsSuccess { get; }
    public double UnitTestsCoverage { get; }
    public string GeneratedSolutionFileDirectory { get; }
    public ICollection<GAssemblyGroup> CollectionOfAssembliesBuilt { get; }
    public bool PackagingSuccess { get; }
    public bool DeploymentSuccess { get; }

}
}
