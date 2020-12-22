using System;
using System.Collections.Generic;
using System.Threading;
using System.Threading.Tasks;

using ATAP.Utilities.ETW;
using ATAP.Utilities.Philote;
using ATAP.Utilities.Persistence;
namespace ATAP.Utilities.GenerateProgram {
  public static class EntryPoints {
        public static IGGenerateProgramResult GenerateProgramAsync(IGAssemblyGroupSignil gAssemblyGroupSignil = default, IGGlobalSettingsSignil gGlobalSettingsSignil = default, IGSolutionSignil gSolutionSignil = default, IGGenerateProgramProgress generateProgramProgress = default, IPersistence<IInsertResultsAbstract> persistence = default, IPickAndSave<IInsertResultsAbstract> pickAndSave = default, CancellationToken cancellationToken = default) {
        }

    public static IGGenerateProgramResult GenerateProgramAsync(IGAssemblyGroupSignil gAssemblyGroupSignil = default, IGGlobalSettingsSignil gGlobalSettingsSignil = default, IGSolutionSignil gSolutionSignil = default, IGGenerateProgramProgress generateProgramProgress = default, IPersistence<IInsertResultsAbstract> persistence = default, IPickAndSave<IInsertResultsAbstract> pickAndSave = default, CancellationToken cancellationToken = default) {
       IGAssemblyGroupSignil _gAssemblyGroupSignil = gAssemblyGroupSignil ?? throw new ArgumentNullException(nameof(gAssemblyGroupSignil));
       IGGlobalSettingsSignil _gGlobalSettingsSignil = gGlobalSettingsSignil ?? throw new ArgumentNullException(nameof(gGlobalSettingsSignil));
       IGSolutionSignil _gSolutionSignil = gSolutionSignil ?? throw new ArgumentNullException(nameof(gSolutionSignil));
      //  IGGenerateProgramProgress _generateProgramProgress = generateProgramProgress == default ? newGGenerateProgramProgress : generateProgramProgress;
      //  IPersistence<IInsertResultsAbstract> _persistence =
      //  IPickAndSave<IInsertResultsAbstract> _pickAndSave =
      //  CancellationToken _cancellationToken =
      // local variables to be used in creating the results
      bool DBExtractionSuccess = false;
      bool BuildSuccess = false;
      bool UnitTestsSuccess = false;
      double UnitTestsCoverage = 0.0;
      string GeneratedSolutionFileDirectory = "";
      ICollection<GAssemblyGroup> CollectionOfAssembliesBuilt = new SortedSet<GAssemblyGroup>();
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

      GGenerateProgramResult gGenerateProgramResult = null;
      return gGenerateProgramResult;
    }
  }
}
