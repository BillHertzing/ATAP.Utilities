using System;
using System.Collections.Generic;
using System.Threading;
using System.Threading.Tasks;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Localization;
using Microsoft.Extensions.Logging;

using ATAP.Utilities.ETW;
using ATAP.Utilities.Philote;
using ATAP.Utilities.Persistence;
using ATAP.Utilities.GenerateProgram;
namespace ATAP.Services.HostedService.GenerateProgram {
  public interface IGenerateProgramHostedService {
    IGenerateProgramHostedServiceData ServiceData { get; }
    IGGenerateProgramResult InvokeGenerateProgram(IGInvokeGenerateCodeSignil gInvokeGenerateCodeSignil);
    // IGGenerateProgramResult InvokeGenerateProgram(IGAssemblyGroupSignil gAssemblyGroupSignil, IGGlobalSettingsSignil gGlobalSettingsSignil, IGSolutionSignil gSolutionSignil, IGGenerateCodeProgressReport gGenerateCodeProgressReport, IPersistence<IInsertResultsAbstract> persistence, IPickAndSave<IInsertResultsAbstract> pickAndSave, CancellationToken cancellationToken);
    // IGGenerateProgramResult InvokeGenerateProgram(IPhilote<IGAssemblyGroupSignil> gAssemblyGroupSignilKey, IPhilote<IGGlobalSettingsSignil> gGlobalSettingsSignilKey, IPhilote<IGSolutionSignil> gSolutionSignilKey, IGGenerateCodeProgressReport gGenerateCodeProgressReport, IPersistence<IInsertResultsAbstract> persistence, IPickAndSave<IInsertResultsAbstract> pickAndSave, CancellationToken cancellationToken);
    // Task<IGGenerateProgramResult> InvokeGenerateProgramAsync(IGAssemblyGroupSignil gAssemblyGroupSignil, IGGlobalSettingsSignil gGlobalSettingsSignil, IGSolutionSignil gSolutionSignil, IGGenerateCodeProgressReport gGenerateCodeProgressReport, IPersistence<IInsertResultsAbstract> persistence, IPickAndSave<IInsertResultsAbstract> pickAndSave, CancellationToken cancellationToken);
    // Task<IGGenerateProgramResult> InvokeGenerateProgramAsync(IPhilote<IGAssemblyGroupSignil> gAssemblyGroupSignilKey, IPhilote<IGGlobalSettingsSignil> gGlobalSettingsSignilKey, IPhilote<IGSolutionSignil> gSolutionSignilKey, IGGenerateCodeProgressReport gGenerateCodeProgressReport, IPersistence<IInsertResultsAbstract> persistence, IPickAndSave<IInsertResultsAbstract> pickAndSave, CancellationToken cancellationToken);

    Task StartAsync(CancellationToken externalCancellationToken);
    Task StopAsync(CancellationToken cancellationToken);

    void Dispose();
  }

}
