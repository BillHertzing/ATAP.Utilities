using System;
using System.Text;
using System.Threading;
using System.Threading.Tasks;

using ATAP.Utilities.StronglyTypedId;

namespace ATAP.Utilities.GenerateProgram {
    public interface IGenerateProgramId<TValue> : IAbstractStronglyTypedId<TValue> where TValue : notnull {}
  public interface IGenerateProgram<TValue> where TValue : notnull {

    Task<IGGenerateProgramResult<TValue>> GenerateProgramAsync(IGAssemblyGroupSignil<TValue> gAssemblyGroupSignil, IGGlobalSettingsSignil<TValue> gGlobalSettingsSignil, IGSolutionSignil<TValue> gSolutionSignil);
  }
}
