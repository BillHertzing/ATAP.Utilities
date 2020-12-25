using System.Threading;
using System.Threading.Tasks;

using ATAP.Utilities.Persistence;
namespace ATAP.Utilities.GenerateProgram {
  public interface IEntryPoints {
    IGGenerateProgramResult GenerateProgram(IGGenerateCodeSignil gGenerateCodeSignil = default);
    Task<IGGenerateProgramResult> GenerateProgramAsync(IGGenerateCodeSignil gGenerateCodeSignil = default);
    IGGenerateProgramResult GenerateProgram(IGAssemblyGroupSignil gAssemblyGroupSignil = default, IGGlobalSettingsSignil gGlobalSettingsSignil = default, IGSolutionSignil gSolutionSignil = default);
    IGGenerateProgramResult GenerateProgram(IGAssemblyGroupSignil gAssemblyGroupSignil = default, IGGlobalSettingsSignil gGlobalSettingsSignil = default, IGSolutionSignil gSolutionSignil = default, IGGenerateCodeProgress gGenerateCodeProgressReport = default, IPersistence<IInsertResultsAbstract> persistence = default , IPickAndSave<IInsertResultsAbstract> pickAndSave = default , CancellationToken cancellationToken = default);
  }
}
