using System;
using System.Collections.Generic;
using System.Threading;
using System.Threading.Tasks;

using ATAP.Utilities.ETW;
using ATAP.Utilities.Philote;
using ATAP.Utilities.Persistence;
namespace ATAP.Utilities.GenerateProgram {

  public class EntryPoints : IEntryPoints {
    IGSolutionSignil GSolutionSignil { get; set; }
    IGGlobalSettingsSignil GGlobalSettingsSignil { get; set; }
    IGAssemblyGroupSignil GAssemblyGroupSignil { get; set; }
    IGGenerateCodeProgress? GenerateCodeProgressReport { get; set; }
    IPersistence<IInsertResultsAbstract>? Persistence { get; set; }
    IPickAndSave<IInsertResultsAbstract>? PickAndSave { get; set; }
    CancellationToken? CancellationTokenFromCaller { get; set; }
    bool DBExtractionSuccess { get; set; }
    bool BuildSuccess { get; set; }
    bool UnitTestsSuccess { get; set; }
    double UnitTestsCoverage { get; set; }
    string GeneratedSolutionFileDirectory { get; set; }
    ICollection<GAssemblyGroup> CollectionOfAssembliesBuilt { get; set; }
    bool PackagingSuccess { get; set; }
    bool DeploymentSuccess { get; set; }
    public IGGenerateProgramResult GenerateProgram(IGGenerateCodeSignil gGenerateCodeSignil = default){
      return GenerateProgram(
         gAssemblyGroupSignil: gGenerateCodeSignil.GAssemblyGroupSignil
        , gGlobalSettingsSignil: gGenerateCodeSignil.GGlobalSettingsSignil
        , gSolutionSignil: gGenerateCodeSignil.GSolutionSignil
        , gGenerateCodeProgress: gGenerateCodeSignil.Progress
        , persistence: gGenerateCodeSignil.Persistence
        , pickAndSave: gGenerateCodeSignil.PickAndSave
        , cancellationTokenFromCaller: gGenerateCodeSignil.CancellationTokenFromCaller
      );
      }
    public IGGenerateProgramResult GenerateProgram(IGAssemblyGroupSignil gAssemblyGroupSignil = default, IGGlobalSettingsSignil gGlobalSettingsSignil = default, IGSolutionSignil gSolutionSignil = default) {
      return GenerateProgram(gAssemblyGroupSignil, gGlobalSettingsSignil, gSolutionSignil, default, default, default);
    }
    public IGGenerateProgramResult GenerateProgram(IGAssemblyGroupSignil gAssemblyGroupSignil = default,
    IGGlobalSettingsSignil gGlobalSettingsSignil = default, IGSolutionSignil gSolutionSignil = default
    , IGGenerateCodeProgress gGenerateCodeProgress = default
    , IPersistence<IInsertResultsAbstract> persistence = default
    , IPickAndSave<IInsertResultsAbstract> pickAndSave = default
    , CancellationToken cancellationTokenFromCaller = default) {
      GAssemblyGroupSignil = gAssemblyGroupSignil ?? throw new ArgumentNullException(nameof(gAssemblyGroupSignil));
      GGlobalSettingsSignil = gGlobalSettingsSignil ?? throw new ArgumentNullException(nameof(gGlobalSettingsSignil));
      GSolutionSignil = gSolutionSignil ?? throw new ArgumentNullException(nameof(gSolutionSignil));
      GenerateCodeProgressReport = gGenerateCodeProgress == default ? new GGenerateCodeProgress() : gGenerateCodeProgress;
      Persistence = persistence == default ? null : persistence;
      PickAndSave = pickAndSave == default ? null : pickAndSave;
      CancellationTokenFromCaller = cancellationTokenFromCaller == default ? null: cancellationTokenFromCaller;
     // local variables to be used in creating the results
     bool DBExtractionSuccess = false;
      bool BuildSuccess = false;
      bool UnitTestsSuccess = false;
      double UnitTestsCoverage = 0.0;
      string GeneratedSolutionFileDirectory = "";
      ICollection<IGAssemblyGroup> CollectionOfAssembliesBuilt = new SortedSet<IGAssemblyGroup>();
      bool PackagingSuccess = false;
      bool DeploymentSuccess = false;
      // create the MCreateSolutionGroupSignil from the GlobalSettingsSignil and the SolutionGroupSignil
      // call MCreateSolutionGroup for the SolutionGroupKey
      // execute the powershell program, passing it the dotnet build command
      // Get the AssemblyGroupKey from the DB using the ProgramKey
      // For any dependencies that are in lifecyclestage other than production
      // Get a collection of AssemblyGroupKeys from the DB using the ProgramKey and the list of dependencies that are in lifecyclestage Development
      // Iterate the dependencies collection in parallel
      // get the AssemblyGroupSignil from the DB for each AssemblyGroupKey
      // create the MCreateAssemblyGroupSignil from the GlobalSettingsSignil and the AssemblyGroupSignil
      // call MCreateAssemblyGroup for each AssemblygroupKey
      // execute the powershell program, passing it the dotnet build command
      // execute the powershell program, passing it the dotnet test command
      // get the AssemblyGroupSignil from the DB for the ProgramKey
      // create the MCreateAssemblyGroupSignil from the GlobalSettingsSignil and the AssemblyGroupSignil
      // call MCreateAssemblyGroup for the ProgramKey
      // execute the powershell program, passing it the dotnet build command
      
      GGenerateProgramResult gGenerateProgramResult = new GGenerateProgramResult(DBExtractionSuccess, BuildSuccess, UnitTestsSuccess, UnitTestsCoverage, GeneratedSolutionFileDirectory, CollectionOfAssembliesBuilt, PackagingSuccess, DeploymentSuccess);
      return gGenerateProgramResult;
    }
  }
}
