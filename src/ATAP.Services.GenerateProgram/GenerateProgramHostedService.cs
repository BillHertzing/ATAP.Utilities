using System;
using System.Collections.Generic;
using System.Diagnostics;
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

using hostedServiceStringConstants = ATAP.Services.HostedService.GenerateProgram.StringConstants;

namespace ATAP.Services.HostedService.GenerateProgram {

#if TRACE
  [ETWLogAttribute]
#endif
  public partial class GenerateProgramHostedService : IHostedService, IDisposable, IGenerateProgramHostedService {
    #region Common Constructor-injected Auto-Implemented Properties and Localizers
    // These properties can only be set in the class constructor.
    // Class constructor for a Hosted Service is called from the GenericHost which injects the DI services referenced in the Constructor Signature
    ILoggerFactory loggerFactory { get; }
    ILogger<GenerateProgramHostedService> logger { get; }
    IStringLocalizerFactory stringLocalizerFactory { get; }
    IHostEnvironment hostEnvironment { get; }
    IConfiguration hostConfiguration { get; }
    IHostLifetime hostLifetime { get; }
    IConfiguration hostedServiceConfiguration { get; }
    IHostApplicationLifetime hostApplicationLifetime { get; }
    IStringLocalizer debugLocalizer { get; }
    IStringLocalizer exceptionLocalizer { get; }
    IStringLocalizer uiLocalizer { get; }

    #endregion
    #region Internal and Linked CancellationTokenSource and Tokens
    CancellationTokenSource InternalCancellationTokenSource { get; } = new CancellationTokenSource();
    CancellationToken InternalCancellationToken { get; }
    // Set in the ExecuteAsync method
    CancellationTokenSource LinkedCancellationTokenSource { get; set; }
    // Set in the ExecuteAsync method
    CancellationToken LinkedCancellationToken { get; set; }
    #endregion
    /*
    #region Constructor-injected fields unique to this service. These represent other DI services used by this service that are expected to be present in the app's DI container, and are constructor-injected
    #endregion
    */
    #region Data for Service
    public IGenerateProgramHostedServiceData ServiceData { get; }
    #endregion
    #region Performance Monitoring data
    Stopwatch Stopwatch { get; } // ToDo: utilize a much more powerful and ubiquitous timing and profiling tool than a stopwatch
    #endregion
    #region Constructor
    /// <summary>
    /// Constructor that populates all the injected services provided by a GenericHost, along with the injected services specific to this program that are needed by this HostedService (or derivative like BackgroundService)
    /// </summary>
    /// <param name="loggerFactory"></param>
    /// <param name="hostEnvironment"></param>
    /// <param name="hostConfiguration"></param>
    /// <param name="hostLifetime"></param>
    /// <param name="hostApplicationLifetime"></param>
    public GenerateProgramHostedService(ILoggerFactory loggerFactory, IStringLocalizerFactory stringLocalizerFactory, IHostEnvironment hostEnvironment, IConfiguration hostConfiguration, IHostLifetime hostLifetime, IConfiguration hostedServiceConfiguration, IHostApplicationLifetime hostApplicationLifetime) {
      this.stringLocalizerFactory = stringLocalizerFactory ?? throw new ArgumentNullException(nameof(stringLocalizerFactory));
      //exceptionLocalizer = stringLocalizerFactory.Create(nameof(GenerateProgramHostedService.Resources), "Resources");
      //debugLocalizer = stringLocalizerFactory.Create(nameof(GenerateProgramHostedService.Resources), "Resources");
      //uiLocalizer = stringLocalizerFactory.Create(nameof(GenerateProgramHostedService.Resources), "Resources");
      this.loggerFactory = loggerFactory ?? throw new ArgumentNullException(nameof(loggerFactory));
      this.logger = loggerFactory.CreateLogger<GenerateProgramHostedService>();
      // this.logger = (Logger<GenerateProgramHostedService>) ATAP.Utilities.Logging.LogProvider.GetLogger("GenerateProgramHostedService");
      logger.LogDebug("GenerateProgramHostedService", ".ctor");  // ToDo Fody for tracing constructors, via an optional switch
      this.hostEnvironment = hostEnvironment ?? throw new ArgumentNullException(nameof(hostEnvironment));
      this.hostConfiguration = hostConfiguration ?? throw new ArgumentNullException(nameof(hostConfiguration));
      this.hostLifetime = hostLifetime ?? throw new ArgumentNullException(nameof(hostLifetime));
      this.hostedServiceConfiguration = hostedServiceConfiguration ?? throw new ArgumentNullException(nameof(hostedServiceConfiguration));
      this.hostApplicationLifetime = hostApplicationLifetime ?? throw new ArgumentNullException(nameof(hostApplicationLifetime));
      //this.consoleSinkHostedService = consoleSinkHostedService ?? throw new ArgumentNullException(nameof(consoleSinkHostedService));
      //this.consoleSourceHostedService = consoleSourceHostedService ?? throw new ArgumentNullException(nameof(consoleSourceHostedService));
      InternalCancellationToken = InternalCancellationTokenSource.Token;
      Stopwatch = new Stopwatch();
      #region Create the serviceData and initialize it from the StringConstants or this service's ConfigRoot
      this.ServiceData = new GenerateProgramHostedServiceData(
      ){
      // The following parameters are for each invocation of a GenerateProgramAsync call
      // invoking a GenerateProgram call may override any of these values, but absent an override, these are the
      //  default values that will be used for every GenerateProgramAsync call.
      //  the default values come from the ICOnfiguration hostedServiceConfiguration that is DI injected at service startup
      /// ToDo: Security: ensure the paths do not go above their Base directory
        ArtifactsDirectoryBase = hostedServiceConfiguration.GetValue<string>(hostedServiceStringConstants.ArtifactsDirectoryBaseConfigRootKey, hostedServiceStringConstants.ArtifactsDirectoryBaseDefault), // ToDo: should validate in case the hostedServiceStringConstants assembly is messed up?
        ArtifactsFileRelativePath = hostedServiceConfiguration.GetValue<string>(hostedServiceStringConstants.ArtifactsFileRelativePathConfigRootKey, hostedServiceStringConstants.ArtifactsFileRelativePathhDefault),
        EnablePersistence = hostedServiceConfiguration.GetValue<bool>(hostedServiceStringConstants.EnablePersistenceBoolConfigRootKey, bool.Parse(hostedServiceStringConstants.EnablePersistenceBoolDefault)), // ToDo: should validate in case the hostedServiceStringConstants assembly is messed up?
        EnablePickAndSave = hostedServiceConfiguration.GetValue<bool>(hostedServiceStringConstants.EnablePickAndSaveBoolConfigRootKey, bool.Parse(hostedServiceStringConstants.EnablePickAndSaveBoolDefault)), // ToDo: should validate in case the hostedServiceStringConstants assembly is messed up?
        EnableProgress = hostedServiceConfiguration.GetValue<bool>(hostedServiceStringConstants.EnableProgressBoolConfigRootKey, bool.Parse(hostedServiceStringConstants.EnableProgressBoolDefault)), // ToDo: should validate in case the hostedServiceStringConstants assembly is messed up?
        TemporaryDirectoryBase = hostedServiceConfiguration.GetValue<string>(hostedServiceStringConstants.TemporaryDirectoryBaseConfigRootKey, hostedServiceStringConstants.TemporaryDirectoryBaseDefault),
        PersistenceMessageFileRelativePath = hostedServiceConfiguration.GetValue<string>(hostedServiceStringConstants.PersistenceMessageFileRelativePathConfigRootKey, hostedServiceStringConstants.PersistenceMessageFileRelativePathDefault),
        PickAndSaveMessageFileRelativePath = hostedServiceConfiguration.GetValue<string>(hostedServiceStringConstants.PickAndSaveMessageFileRelativePathConfigRootKey, hostedServiceStringConstants.PickAndSaveMessageFileRelativePathDefault),
        DBConnectionString = hostedServiceConfiguration.GetValue<string>(hostedServiceStringConstants.DBConnectionStringConfigRootKey, hostedServiceStringConstants.DBConnectionStringDefault),
        OrmLiteDialectProviderStringDefault = hostedServiceConfiguration.GetValue<string>(hostedServiceStringConstants.OrmLiteDialectProviderConfigRootKey, hostedServiceStringConstants.OrmLiteDialectProviderDefault)
      };
      this.ServiceData.ArtifactsFilePaths = new string[1] { ServiceData.ArtifactsDirectoryBase + ServiceData.ArtifactsFileRelativePath};
      this.ServiceData.PersistenceFilePaths = new string[1] { ServiceData.TemporaryDirectoryBase + ServiceData.PersistenceMessageFileRelativePath};
      this.ServiceData.PickAndSaveFilePaths = new string[1] { ServiceData.TemporaryDirectoryBase + ServiceData.PickAndSaveMessageFileRelativePath};
      // ToDo ?: setup placeholders for the ProgressReport object
      // ToDo ?: setup placeholders for the Persistence(File)
      // ToDo ?: setup placeholders for the PickAndSave object
      // ToDo ?: setup placeholders for the DBConnection object
      // ToDo ?: setup placeholders for the IATAPOrm shim object
      #endregion
    }
    #endregion
    public async Task<IGGenerateProgramResult> GenerateProgramAsync(IPhilote<IGAssemblyGroupSignil> gAssemblyGroupSignilKey, IPhilote<IGGlobalSettingsSignil> gGlobalSettingsSignilKey, IPhilote<IGSolutionSignil> gSolutionSignilKey, IGGenerateProgramProgress generateProgramProgress, IPersistence<IInsertResultsAbstract> persistence, IPickAndSave<IInsertResultsAbstract> pickAndSave, CancellationToken cancellationToken) {
      IGGenerateProgramResult gGenerateProgramResult;
      #region Method timing setup
      Stopwatch stopWatch = new Stopwatch(); // ToDo: utilize a much more powerfull and ubiquitous timing and profiling tool than a stopwatch
      stopWatch.Start();
      #endregion
      try {
        Func<Task<IGGenerateProgramResult>> run = () => ATAP.Utilities.GenerateProgram.GenerateProgramAsync(gAssemblyGroupSignilKey, gGlobalSettingsSignilKey, gSolutionSignilKey, generateProgramProgress, persistence, pickAndSave, cancellationToken);
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
        setupResultsPickAndSave.Dispose();
        setupResultsPersistence.Dispose();
      }
      return gGenerateProgramResult;
    }


    public async Task<IGGenerateProgramResult> GenerateProgramAsync(IGAssemblyGroupSignil gAssemblyGroupSignil, IGGlobalSettingsSignil gGlobalSettingsSignil, IGSolutionSignil gSolutionSignil, IGGenerateProgramProgress generateProgramProgress, IPersistence<IInsertResultsAbstract> persistence, IPickAndSave<IInsertResultsAbstract> pickAndSave, CancellationToken cancellationToken) {
      IGGenerateProgramResult gGenerateProgramResult;
      //
      #region Method timing setup
      Stopwatch stopWatch = new Stopwatch(); // ToDo: utilize a much more powerfull and ubiquitous timing and profiling tool than a stopwatch
      stopWatch.Start();
      #endregion
      try {
        Func<Task<IGGenerateProgramResult>> run = () => ATAP.Utilities.GenerateProgram.GenerateProgramAsync(gAssemblyGroupSignil, gGlobalSettingsSignil, gSolutionSignil, generateProgramProgress, persistence, pickAndSave, cancellationToken);
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
        setupResultsPickAndSave.Dispose();
        setupResultsPersistence.Dispose();
      }
      return gGenerateProgramResult;
    }

    #region StartAsync and StopAsync methods as promised by IHostedService when IHostLifetime is ConsoleLifetime  // ToDo:, see if this is called by service and serviced
    /// <summary>
    /// Called to start the service.
    /// </summary>
    /// <param name="genericHostsCancellationToken"></param> Used to signal FROM the GenericHost TO this IHostedService a request for cancelllation
    /// <returns></returns>
    public async Task StartAsync(CancellationToken genericHostsCancellationToken) {

      #region create linkedCancellationSource and token
      // Combine the cancellation tokens,so that either can stop this HostedService
      //LinkedCancellationTokenSource = CancellationTokenSource.CreateLinkedTokenSource(InternalCancellationToken, genericHostsCancellationToken);

      #endregion
      #region Register actions with the CancellationToken (s)
      genericHostsCancellationToken.Register(() => logger.LogDebug(debugLocalizer["{0} {1} genericHostsCancellationToken has signalled stopping."], "GenerateProgramHostedService", "genericHostsCancellationToken"));
      InternalCancellationToken.Register(() => logger.LogDebug(debugLocalizer["{0} {1} InternalCancellationToken has signalled stopping."], "GenerateProgramHostedService", "InternalCancellationToken"));
      LinkedCancellationToken.Register(() => logger.LogDebug(debugLocalizer["{0} {1} LinkedCancellationToken has signalled stopping."], "GenerateProgramHostedService", "LinkedCancellationToken"));
      #endregion
      #region register local event handlers with the IHostApplicationLifetime's events
      // Register the methods defined in this class with the three CancellationToken properties found on the IHostApplicationLifetime instance passed to this class in it's .ctor
      hostApplicationLifetime.ApplicationStarted.Register(OnStarted);
      hostApplicationLifetime.ApplicationStopping.Register(OnStopping);
      hostApplicationLifetime.ApplicationStopped.Register(OnStopped);
      #endregion
      // Wait to be connected to the stdIn observable
      //return Task.CompletedTask;
    }

    // StopAsync issued in both IHostedService and IHostLifetime interfaces
    // This IS called when the user closes the ConsoleWindow with the windows top right pane "x (close)" icon
    // This IS called when the user hits ctrl-C in the console window
    //  After Ctrl-C and after this method exits, the debugger
    //    shows an unhandled exception: System.OperationCanceledException: 'The operation was canceled.'
    // See also discussion of Stop async in the following attributions.
    // Attribution to  https://stackoverflow.com/questions/51044781/graceful-shutdown-with-generic-host-in-net-core-2-1
    // Attribution to https://stackoverflow.com/questions/52915015/how-to-apply-hostoptions-shutdowntimeout-when-configuring-net-core-generic-host for OperationCanceledException notes

    public async Task StopAsync(CancellationToken cancellationToken) {
      logger.LogDebug(debugLocalizer["{0} {1}  StopAsync ."], "GenerateProgramHostedService", "StopAsync");
      //InternalCancellationTokenSource.Cancel();
      // Defer completion promise, until our application has reported it is done.
      // return TaskCompletionSource.Task;
      //Stop(); // would call the servicebase stop if this was a generic hosted service ??
      //return Task.CompletedTask;
    }
    #endregion

    #region Event Handlers registered with the HostApplicationLifetime events
    // Registered as a handler with the HostApplicationLifetime.ApplicationStarted event
    private void OnStarted() {
      // Post-startup code goes here
    }

    // Registered as a handler with the HostApplicationLifetime.Application event
    // This is NOT called if the ConsoleWindows ends when the connected browser (browser opened by LaunchSettings when starting with debugger) is closed (not applicable to ConsoleLifetime generic hosts
    // This IS called if the user hits ctrl-C in the ConsoleWindow
    private void OnStopping() {
      // On-stopping code goes here
    }

    // Registered as a handler with the HostApplicationLifetime.ApplicationStarted event
    private void OnStopped() {
      // Post-stopped code goes here
    }

    // Called by base.Stop. This may be called multiple times by service Stop, ApplicationStopping, and StopAsync.
    // That's OK because StopApplication uses a CancellationTokenSource and prevents any recursion.
    // This IS called when user hits ctrl-C in ConsoleWindow
    //  This IS NOT called when user closes the startup auto browser
    // ToDo:investigate BrowserLink, and multiple browsers effect on this call
    //protected override void OnStop() {
    //  HostApplicationLifetime.StopApplication();
    //  base.OnStop();
    //}
    #endregion

    #region IDisposable Support
    private bool disposedValue = false; // To detect redundant calls

    protected virtual void Dispose(bool disposing) {
      if (!disposedValue) {
        if (disposing) {
          ServiceData.Dispose();
        }

        // TODO: free unmanaged resources (unmanaged objects) and override a finalizer below.
        // TODO: set large fields to null.

        disposedValue = true;
      }
    }

    // TODO: override a finalizer only if Dispose(bool disposing) above has code to free unmanaged resources.
    // ~ConvertFileSystemGraphToDBDataAndResults()
    // {
    //   // Do not change this code. Put cleanup code in Dispose(bool disposing) above.
    //   Dispose(false);
    // }

    // This code added to correctly implement the disposable pattern.
    public void Dispose() {
      // Do not change this code. Put cleanup code in Dispose(bool disposing) above.
      Dispose(true);
      // TODO: uncomment the following line if the finalizer is overridden above.
      // GC.SuppressFinalize(this);
    }
    #endregion

  }
}
