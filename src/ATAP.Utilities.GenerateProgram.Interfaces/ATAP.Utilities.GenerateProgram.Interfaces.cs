using System;
using System.Text;
using System.Threading;
using System.Threading.Tasks;

namespace ATAP.Utilities.GenerateProgram {
  public interface IGenerateProgram {
    Task<IGGenerateProgramResult> GenerateProgramAsync(IGAssemblyGroupSignil gAssemblyGroupSignil, IGGlobalSettingsSignil gGlobalSettingsSignil, IGSolutionSignil gSolutionSignil);
  }
}
