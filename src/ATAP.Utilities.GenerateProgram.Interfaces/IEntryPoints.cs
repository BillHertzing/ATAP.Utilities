using System.Threading;
using System.Threading.Tasks;

using ATAP.Utilities.Persistence;
namespace ATAP.Utilities.GenerateProgram {
  public interface IEntryPoints {
    IGGenerateProgramResult GenerateProgram(IGAssemblyGroupSignil gAssemblyGroupSignil = null, IGGlobalSettingsSignil gGlobalSettingsSignil = null, IGSolutionSignil gSolutionSignil = null);
    IGGenerateProgramResult GenerateProgram(IGAssemblyGroupSignil gAssemblyGroupSignil = default, IGGlobalSettingsSignil gGlobalSettingsSignil = default, IGSolutionSignil gSolutionSignil = default, IGGenerateCodeProgressReport gGenerateCodeProgressReport = default, IPersistence<IInsertResultsAbstract> persistence = default , IPickAndSave<IInsertResultsAbstract> pickAndSave = default , CancellationToken cancellationToken = default);
  }
}
