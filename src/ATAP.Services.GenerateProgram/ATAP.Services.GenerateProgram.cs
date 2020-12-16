using System;

namespace ATAP.Services.GenerateProgram {
  public class GenerateProgram {
    void Dispose();
    Task StartAsync(CancellationToken externalCancellationToken);
    Task StopAsync(CancellationToken cancellationToken);
    IGGenerateProgramResult GenerateProgramEntryPoint1(IGAssemblyGroupSignil gAssemblyGroupSignil, IGGlobalSettingsSignil gGlobalSettingsSignil, IGSolutionSignil gSolutionSignil);
  }
}
