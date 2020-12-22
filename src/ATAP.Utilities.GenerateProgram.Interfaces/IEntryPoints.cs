using System.Threading;

using ATAP.Utilities.Persistence;
namespace ATAP.Utilities.GenerateProgram {
  public interface IEntryPoints {
    IGGenerateProgramResult GenerateProgramAsync(IGAssemblyGroupSignil gAssemblyGroupSignil = null, IGGlobalSettingsSignil gGlobalSettingsSignil = null, IGSolutionSignil gSolutionSignil = null);
    IGGenerateProgramResult GenerateProgramAsync(IGAssemblyGroupSignil gAssemblyGroupSignil = null, IGGlobalSettingsSignil gGlobalSettingsSignil = null, IGSolutionSignil gSolutionSignil = null, IGGenerateProgramProgress generateProgramProgress = null, IPersistence<IInsertResultsAbstract> persistence = null, IPickAndSave<IInsertResultsAbstract> pickAndSave = null, CancellationToken cancellationToken = default);
  }
}
