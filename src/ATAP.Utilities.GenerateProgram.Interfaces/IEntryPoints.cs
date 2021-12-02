using System.Threading;
using System.Threading.Tasks;

using ATAP.Utilities.Persistence;
namespace ATAP.Utilities.GenerateProgram {
  public interface IEntryPoints<TValue> where TValue : notnull {
    IGGenerateProgramResult<TValue> GenerateProgram(IGGenerateCodeSignil<TValue> gGenerateCodeSignil = default);
    Task<IGGenerateProgramResult<TValue>> GenerateProgramAsync(IGGenerateCodeSignil<TValue> gGenerateCodeSignil = default);
    IGGenerateProgramResult<TValue> GenerateProgram(IGAssemblyGroupSignil<TValue> gAssemblyGroupSignil = default, IGGlobalSettingsSignil<TValue> gGlobalSettingsSignil = default, IGSolutionSignil<TValue> gSolutionSignil = default);
    IGGenerateProgramResult<TValue> GenerateProgram(IGAssemblyGroupSignil<TValue> gAssemblyGroupSignil = default, IGGlobalSettingsSignil<TValue> gGlobalSettingsSignil = default, IGSolutionSignil<TValue> gSolutionSignil = default, IGGenerateCodeProgress<TValue> gGenerateCodeProgressReport = default, IPersistence<IInsertResultsAbstract> persistence = default, IPickAndSave<IInsertResultsAbstract> pickAndSave = default, CancellationToken cancellationToken = default);
  }
}
