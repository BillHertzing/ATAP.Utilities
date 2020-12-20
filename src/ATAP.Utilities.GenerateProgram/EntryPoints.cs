using System.Collections.Generic;
namespace ATAP.Utilities.GenerateProgram {
  public static class EntryPoints {
    public static IGGenerateProgramResult GenerateProgramAsync(IGAssemblyGroupSignil gAssemblyGroupSignil, IGGlobalSettingsSignil gGlobalSettingsSignil, IGSolutionSignil gSolutionSignil) {

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
