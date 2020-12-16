using System;

namespace ATAP.Utilities.GenerateProgram {
  public interface IGenerateProgram {
    void Dispose();
    Task StartAsync(CancellationToken externalCancellationToken);
    Task StopAsync(CancellationToken cancellationToken);
    IGGenerateProgramResult GenerateProgramEntryPoint1(IGAssemblyGroupSignil gAssemblyGroupSignil, IGGlobalSettingsSignil gGlobalSettingsSignil, IGSolutionSignil gSolutionSignil);
  }
}
