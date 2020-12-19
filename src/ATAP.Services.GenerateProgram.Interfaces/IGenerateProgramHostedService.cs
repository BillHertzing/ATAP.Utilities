using System;
using System.Collections.Generic;
using System.Threading;
using System.Threading.Tasks;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Localization;
using Microsoft.Extensions.Logging;

using ATAP.Utilities.ETW;
using ATAP.Utilities.GenerateProgram;
namespace ATAP.Services.HostedService.GenerateProgram {
  public interface IGenerateProgramHostedService {
    IGenerateProgramHostedServiceData ServiceData { get; }
    Task<IGGenerateProgramResult> GenerateProgramAsync(IGAssemblyGroupSignil gAssemblyGroupSignil, IGGlobalSettingsSignil gGlobalSettingsSignil, IGSolutionSignil gSolutionSignil, IGenerateProgramProgress generateProgramProgress, IPersistence<IInsertResultsAbstract> persistence, IPickAndSave<IInsertResultsAbstract> pickAndSave, CancellationToken cancellationToken);
    Task StartAsync(CancellationToken externalCancellationToken);
    Task StopAsync(CancellationToken cancellationToken);

    void Dispose();
  }

}
