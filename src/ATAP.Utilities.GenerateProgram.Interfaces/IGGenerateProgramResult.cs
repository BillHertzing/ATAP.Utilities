using System.Collections.Generic;
using ATAP.Utilities.Philote;

namespace ATAP.Utilities.GenerateProgram {  public interface IGGenerateProgramResult {
    bool DBExtractionSuccess { get; init; }
    bool BuildSuccess { get; init; }
    bool UnitTestsSuccess { get; init; }
    double UnitTestsCoverage { get; init; }
    string GeneratedSolutionFileDirectory { get; init; }
    ICollection<IGAssemblyGroup> CollectionOfAssembliesBuilt { get; init; }
    bool PackagingSuccess { get; init; }
    bool DeploymentSuccess { get; init; }
    IPhilote<IGGenerateProgramResult> Philote { get; init; }
  }

}
