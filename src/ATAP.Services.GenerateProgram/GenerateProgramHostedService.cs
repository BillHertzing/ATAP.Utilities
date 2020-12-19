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
    CancellationTokenSource internalCancellationTokenSource { get; } = new CancellationTokenSource();
    CancellationToken internalCancellationToken { get; }
    // Set in the ExecuteAsync method
    CancellationTokenSource linkedCancellationTokenSource { get; set; }
    // Set in the ExecuteAsync method
    CancellationToken linkedCancellationToken { get; set; }
    #endregion
    /*
    #region Constructor-injected fields unique to this service. These represent other DI services used by this service that are expected to be present in the app's DI container, and are constructor-injected
    #endregion
    */
    #region Data for Service
    public GenerateProgramHostedServiceData ServiceData { get; }
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
      exceptionLocalizer = stringLocalizerFactory.Create(nameof(GenerateProgramHostedService.Resources), "GenerateProgramHostedService");
      debugLocalizer = stringLocalizerFactory.Create(nameof(GenerateProgramHostedService.Resources), "GenerateProgramHostedService");
      uiLocalizer = stringLocalizerFactory.Create(nameof(GenerateProgramHostedService.Resources), "GenerateProgramHostedService");
      this.loggerFactory = loggerFactory ?? throw new ArgumentNullException(nameof(loggerFactory));
      this.logger = loggerFactory.CreateLogger<GenerateProgramHostedService>();
      // this.logger = (Logger<GenerateProgramHostedService>) ATAP.Utilities.Logging.LogProvider.GetLogger("GenerateProgramHostedService");
      logger.LogDebug("GenerateProgramHostedService", ".ctor");  // ToDo Fody for tracing constructors, via an optional switch
      this.hostEnvironment = hostEnvironment ?? throw new ArgumentNullException(nameof(hostEnvironment));
      this.hostConfiguration = hostConfiguration ?? throw new ArgumentNullException(nameof(hostConfiguration));
      this.hostLifetime = hostLifetime ?? throw new ArgumentNullException(nameof(hostLifetime));
      this.hostedServiceConfiguration = hostedServiceConfiguration ?? throw new ArgumentNullException(nameof(hostedServiceConfiguration));
      this.hostApplicationLifetime = hostApplicationLifetime ?? throw new ArgumentNullException(nameof(hostApplicationLifetime));
      this.consoleSinkHostedService = consoleSinkHostedService ?? throw new ArgumentNullException(nameof(consoleSinkHostedService));
      this.consoleSourceHostedService = consoleSourceHostedService ?? throw new ArgumentNullException(nameof(consoleSourceHostedService));
      internalCancellationToken = internalCancellationTokenSource.Token;
      Stopwatch = new Stopwatch();
      #region Create the serviceData and initialize it from the StringConstants or this service's ConfigRoot
      this.ServiceData = new GenerateProgramHostedServiceData(
        TemporaryDirectoryBase = hostedServiceConfiguration.GetValue<string>(hostedServiceStringConstants.TemporaryDirectoryBaseConfigRootKey, hostedServiceStringConstants.TemporaryDirectoryBaseDefault),

        // ToDo: Get the list from the StringConstants, and localize them
        choices: new List<string>() { "1. Run FileSystemToObjectGrapAsyncTask", "2. Changeable", "99: Quit this service" },
        stdInHandlerState: new StringBuilder(),
        mesg: new StringBuilder()) {
        AsyncFileReadBlockSize = hostedServiceConfiguration.GetValue<int>(hostedServiceStringConstants.AsyncFileReadBlockSizeConfigRootKey, int.Parse(hostedServiceStringConstants.AsyncFileReadBlockSizeDefault)),  // ToDo: should validate in case the hostedServiceStringConstants assembly is messed up?
        EnableHash = hostedServiceConfiguration.GetValue<bool>(hostedServiceStringConstants.EnableHashBoolConfigRootKey, bool.Parse(hostedServiceStringConstants.EnableHashBoolDefault)), // ToDo: should validate in case the hostedServiceStringConstants assembly is messed up?
        EnablePersistence = hostedServiceConfiguration.GetValue<bool>(hostedServiceStringConstants.EnablePersistenceBoolConfigRootKey, bool.Parse(hostedServiceStringConstants.EnablePersistenceBoolDefault)), // ToDo: should validate in case the hostedServiceStringConstants assembly is messed up?
        EnablePickAndSave = hostedServiceConfiguration.GetValue<bool>(hostedServiceStringConstants.EnablePickAndSaveBoolConfigRootKey, bool.Parse(hostedServiceStringConstants.EnablePickAndSaveBoolDefault)), // ToDo: should validate in case the hostedServiceStringConstants assembly is messed up?
        EnableProgress = hostedServiceConfiguration.GetValue<bool>(hostedServiceStringConstants.EnableProgressBoolConfigRootKey, bool.Parse(hostedServiceStringConstants.EnableProgressBoolDefault)), // ToDo: should validate in case the hostedServiceStringConstants assembly is messed up?
        DBConnectionString = "",
        OrmLiteDialectProviderStringDefault = "",
      };
      this.ServiceData.PersistenceFilePaths = new string[2] { ServiceData.TemporaryDirectoryBase + ServiceData.PersistenceNodeFileRelativePath, ServiceData.TemporaryDirectoryBase + ServiceData.PersistenceEdgeFileRelativePath };
      //ToDo: setup Progress here?
      #endregion
    }
    #endregion

    public async Task<IGGenerateProgramResult> GenerateProgramAsync(IPhilote<IGAssemblyGroupSignil> gAssemblyGroupSignilKey, IPhilote<IGGlobalSettingsSignil> gGlobalSettingsSignilKey, IPhilote<IGSolutionSignil> gSolutionSignilKey, IGenerateProgramProgress generateProgramProgress, IPersistence<IInsertResultsAbstract> persistence, IPickAndSave<IInsertResultsAbstract> pickAndSave, CancellationToken cancellationToken) {
      IGGenerateProgramResult gGenerateProgramResult;
      #region Method timing setup
      Stopwatch stopWatch = new Stopwatch(); // ToDo: utilize a much more powerfull and ubiquitous timing and profiling tool than a stopwatch
      stopWatch.Start();
      #endregion
      try {
        Func<Task<IGGenerateProgramResult>> run = () => ATAP.Utilities.GenerateProgramAsync(gAssemblyGroupSignilKey,  gGlobalSettingsSignilKey,  gSolutionSignilKey, generateProgramProgress, persistence, pickAndSave, cancellationToken);
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
      return  gGenerateProgramResult;
    }

    public async Task<IGGenerateProgramResult> GenerateProgramAsync(IGAssemblyGroupSignil gAssemblyGroupSignil, IGGlobalSettingsSignil gGlobalSettingsSignil, IGSolutionSignil gSolutionSignil, IGenerateProgramProgress generateProgramProgress, IPersistence<IInsertResultsAbstract> persistence, IPickAndSave<IInsertResultsAbstract> pickAndSave, CancellationToken cancellationToken) {
      IGGenerateProgramResult gGenerateProgramResult;
      #region Method timing setup
      Stopwatch stopWatch = new Stopwatch(); // ToDo: utilize a much more powerfull and ubiquitous timing and profiling tool than a stopwatch
      stopWatch.Start();
      #endregion
      try {
        Func<Task<IGGenerateProgramResult>> run = () => ATAP.Utilities.GenerateProgramAsync(gAssemblyGroupSignil, gGlobalSettingsSignil, gGlobalKeysSignil, generateProgramProgress, persistence, pickAndSave, cancellationToken);
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
      return  gGenerateProgramResult;
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
      //linkedCancellationTokenSource = CancellationTokenSource.CreateLinkedTokenSource(internalCancellationToken, externalCancellationToken);
      GenericHostsCancellationToken = genericHostsCancellationToken;
      #endregion
      #region Register actions with the CancellationToken (s)
      GenericHostsCancellationToken.Register(() => logger.LogDebug(debugLocalizer["{0} {1} GenericHostsCancellationToken has signalled stopping."], "GenerateProgramHostedService", "StartAsync"));
      internalCancellationToken.Register(() => logger.LogDebug(debugLocalizer["{0} {1} internalCancellationToken has signalled stopping."], "GenerateProgramHostedService", "internalCancellationToken"));
      linkedCancellationToken.Register(() => logger.LogDebug(debugLocalizer["{0} {1} linkedCancellationToken has signalled stopping."], "GenerateProgramHostedService", "linkedCancellationToken"));
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
          ConvertFileSystemGraphToDBData.Dispose();
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
