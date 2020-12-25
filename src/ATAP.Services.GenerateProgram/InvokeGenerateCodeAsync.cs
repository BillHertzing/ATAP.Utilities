using System;
using System.Diagnostics;
using System.Threading.Tasks;
using Microsoft.Extensions.Hosting;
using ATAP.Utilities.GenerateProgram;
namespace ATAP.Services.GenerateCode {

  public partial class GenerateProgramHostedService : IHostedService, IDisposable, IGenerateProgramHostedService {

          public async Task<IGGenerateProgramResult> InvokeGenerateProgramAsync(IGInvokeGenerateCodeSignil gInvokeGenerateCodeSignil = default) {
      IGGenerateProgramResult gGenerateProgramResult;
      #region Method timing setup
      Stopwatch stopWatch = new Stopwatch(); // ToDo: utilize a much more powerfull and ubiquitous timing and profiling tool than a stopwatch
      stopWatch.Start();
      #endregion
      try {
        Func<Task<IGGenerateProgramResult>> run = () =>
          //gInvokeGenerateCodeSignil.EntryPoints.GenerateProgramAsync(gAssemblyGroupSignilKey, gGlobalSettingsSignilKey, gSolutionSignilKey, gGenerateProgramProgress, persistence, pickAndSave, cancellationToken);
          gInvokeGenerateCodeSignil.EntryPoints.GenerateProgramAsync(gInvokeGenerateCodeSignil);
        gGenerateProgramResult = await run.Invoke().ConfigureAwait(false);
        stopWatch.Stop(); // ToDo: utilize a much more powerfull and ubiquitous timing and profiling tool than a stopwatch
                          // ToDo: put the results someplace
      }
      catch (Exception) { // ToDo: define explicit exceptions to catch and report upon
                          // ToDo: catch FileIO.FileNotFound, sometimes the file disappears
        throw;
      }
      finally {
        // Dispose of the objects that need disposing
      }
      return gGenerateProgramResult;
    }

    }
}
