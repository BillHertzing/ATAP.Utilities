using System;
using System.Text;
using System.Threading;
using System.Threading.Tasks;

namespace ATAP.Utilities.GenerateProgram {
  public interface IGenerateProgram {
    IGGenerateProgramResult GenerateProgramAsync(IGAssemblyGroupSignil gAssemblyGroupSignil, IGGlobalSettingsSignil gGlobalSettingsSignil, IGSolutionSignil gSolutionSignil);
  }
}
