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

using hostedServiceStringConstants = ATAP.Services.GenerateCode.StringConstants;

namespace ATAP.Services.GenerateCode {

#if TRACE
  [ETWLogAttribute]
#endif
  public partial class GenerateProgramHostedService : IHostedService, IDisposable, IGenerateProgramHostedService {
    #region Common Constructor-injected Auto-Implemented Properties and Localizers
    // These properties can only be set in the class constructor.
    // Class constructor for a Hosted Service is called from the GenericHost which injects the DI services referenced in the Constructor Signature
    ILoggerFactory LoggerFactory { get; }
    ILogger<GenerateProgramHostedService> Logger { get; }
    IStringLocalizerFactory StringLocalizerFactory { get; }
    IHostEnvironment HostEnvironment { get; }
    IConfiguration HostConfiguration { get; }
    IHostLifetime HostLifetime { get; }
    IConfiguration HostedServiceConfiguration { get; }
    IHostApplicationLifetime HostApplicationLifetime { get; }
    IStringLocalizer DebugLocalizer { get; }
    IStringLocalizer ExceptionLocalizer { get; }
    IStringLocalizer UiLocalizer { get; }

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
    public IGenerateProgramHostedServiceData ServiceData { get; set; }
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
      StringLocalizerFactory = stringLocalizerFactory ?? throw new ArgumentNullException(nameof(stringLocalizerFactory));
      ExceptionLocalizer = StringLocalizerFactory.Create(typeof(ATAP.Services.GenerateProgram.ExceptionResources));
      DebugLocalizer = StringLocalizerFactory.Create(typeof(ATAP.Services.GenerateProgram.DebugResources));
      UiLocalizer = StringLocalizerFactory.Create(typeof(ATAP.Services.GenerateProgram.UIResources));
      LoggerFactory = loggerFactory ?? throw new ArgumentNullException(nameof(loggerFactory));
      Logger = loggerFactory.CreateLogger<GenerateProgramHostedService>();
      // Logger = (Logger<GenerateProgramHostedService>) ATAP.Utilities.Logging.LogProvider.GetLogger("GenerateProgramHostedService");
      Logger.LogDebug("GenerateProgramHostedService", ".ctor");  // ToDo Fody for tracing constructors, via an optional switch
      HostEnvironment = hostEnvironment ?? throw new ArgumentNullException(nameof(hostEnvironment));
      HostConfiguration = hostConfiguration ?? throw new ArgumentNullException(nameof(hostConfiguration));
      HostLifetime = hostLifetime ?? throw new ArgumentNullException(nameof(hostLifetime));
      HostedServiceConfiguration = hostedServiceConfiguration ?? throw new ArgumentNullException(nameof(hostedServiceConfiguration));
      HostApplicationLifetime = hostApplicationLifetime ?? throw new ArgumentNullException(nameof(hostApplicationLifetime));
      InternalCancellationToken = InternalCancellationTokenSource.Token;
      Stopwatch = new Stopwatch();
      #region Create the serviceData and initialize it from the StringConstants or this service's ConfigRoot
      Logger.LogDebug(DebugLocalizer["Creating ServiceData"]);

      ServiceData = new GenerateProgramHostedServiceData();
      // populate the servicedata tasks list with a single tuple for development

      // The following parameters are for each invocation of a InvokeGenerateProgramAsync call
      // invoking a GenerateProgram call may override any of these values, but absent an override, these are the
      //  default values that will be used for every InvokeGenerateProgramAsync call.
      //  the default values come from the IConfiguration HostedServiceConfiguration that is DI injected at service startup
      /// ToDo: Security: ensure the paths do not go above their Base directory

      // var gInvokeGenerateCodeSignilDefault = new GInvokeGenerateCodeSignil(
      //   new GAssemblyGroupSignil(), new GGlobalSettingsSignil(), new GSolutionSignil(),
      //   artifactsDirectoryBase: hostedServiceConfiguration.GetValue<string>(hostedServiceStringConstants.ArtifactsDirectoryBaseConfigRootKey, hostedServiceStringConstants.ArtifactsDirectoryBaseDefault), // ToDo: should validate in case the hostedServiceStringConstants assembly is messed up?
      //   artifactsFileRelativePath: hostedServiceConfiguration.GetValue<string>(hostedServiceStringConstants.ArtifactsFileRelativePathConfigRootKey, hostedServiceStringConstants.ArtifactsFileRelativePathDefault),
      //   enablePersistence: hostedServiceConfiguration.GetValue<bool>(hostedServiceStringConstants.EnablePersistenceBoolConfigRootKey, bool.Parse(hostedServiceStringConstants.EnablePersistenceBoolDefault)), // ToDo: should validate in case the hostedServiceStringConstants assembly is messed up?
      //   enablePickAndSave: hostedServiceConfiguration.GetValue<bool>(hostedServiceStringConstants.EnablePickAndSaveBoolConfigRootKey, bool.Parse(hostedServiceStringConstants.EnablePickAndSaveBoolDefault)), // ToDo: should validate in case the hostedServiceStringConstants assembly is messed up?
      //   enableProgress: hostedServiceConfiguration.GetValue<bool>(hostedServiceStringConstants.EnableProgressBoolConfigRootKey, bool.Parse(hostedServiceStringConstants.EnableProgressBoolDefault)), // ToDo: should validate in case the hostedServiceStringConstants assembly is messed up?
      //   temporaryDirectoryBase: hostedServiceConfiguration.GetValue<string>(hostedServiceStringConstants.TemporaryDirectoryBaseConfigRootKey, hostedServiceStringConstants.TemporaryDirectoryBaseDefault),
      //   persistenceMessageFileRelativePath: hostedServiceConfiguration.GetValue<string>(hostedServiceStringConstants.PersistenceMessageFileRelativePathConfigRootKey, hostedServiceStringConstants.PersistenceMessageFileRelativePathDefault),
      //   pickAndSaveMessageFileRelativePath: hostedServiceConfiguration.GetValue<string>(hostedServiceStringConstants.PickAndSaveMessageFileRelativePathConfigRootKey, hostedServiceStringConstants.PickAndSaveMessageFileRelativePathDefault),
      //   dBConnectionString: hostedServiceConfiguration.GetValue<string>(hostedServiceStringConstants.DBConnectionStringConfigRootKey, hostedServiceStringConstants.DBConnectionStringDefault),
      //   ormLiteDialectProviderStringDefault: hostedServiceConfiguration.GetValue<string>(hostedServiceStringConstants.OrmLiteDialectProviderConfigRootKey, hostedServiceStringConstants.OrmLiteDialectProviderDefault)
      // );
      // // Every invocation to GenerateProgram needs an instance of an EntryPoint class
      // gInvokeGenerateCodeSignilDefault.EntryPoints = new ATAP.Utilities.GenerateProgram.EntryPoints();
      // gInvokeGenerateCodeSignilDefault.ArtifactsFilePaths = new string[1] { gInvokeGenerateCodeSignilDefault.ArtifactsDirectoryBase + gInvokeGenerateCodeSignilDefault.ArtifactsFileRelativePath };
      // gInvokeGenerateCodeSignilDefault.PersistenceFilePaths = new string[1] { gInvokeGenerateCodeSignilDefault.TemporaryDirectoryBase + gInvokeGenerateCodeSignilDefault.PersistenceMessageFileRelativePath };
      // gInvokeGenerateCodeSignilDefault.PickAndSaveFilePaths = new string[1] { gInvokeGenerateCodeSignilDefault.TemporaryDirectoryBase + gInvokeGenerateCodeSignilDefault.PickAndSaveMessageFileRelativePath };
      // // ToDo ?: setup placeholders for the ProgressReport object
      // // ToDo ?: setup placeholders for the Persistence(File)
      // // ToDo ?: setup placeholders for the PickAndSave object
      #endregion
    }
    #endregion

    public IGGenerateProgramResult InvokeGenerateProgram(IGInvokeGenerateCodeSignil gInvokeGenerateCodeSignil = default) {
      IGGenerateProgramResult gGenerateProgramResult = default;
      #region Method timing setup
      Stopwatch stopWatch = new Stopwatch(); // ToDo: utilize a much more powerfull and ubiquitous timing and profiling tool than a stopwatch
      stopWatch.Start();

      #endregion
      try {
        gGenerateProgramResult = gInvokeGenerateCodeSignil.EntryPoints.GenerateProgram(gInvokeGenerateCodeSignil);
        stopWatch.Stop(); // ToDo: utilize a much more powerfull and ubiquitous timing and profiling tool than a stopwatch
                          // ToDo: put the results someplace
      }
      catch (Exception) { // ToDo: define explicit exceptions to catch and report upon
                          // ToDo: catch FileIO.FileNotFound, sometimes the file disappears
        throw;
      }
      finally {
        // Dispose of the objects that need disposing
        // SetupResults for PickAndSave, Persistence,and Progress (?) should be disposed in the routine that created them
      }
      return gGenerateProgramResult;
    }

    // public async Task<IGGenerateProgramResult> InvokeGenerateProgramAsync(IGAssemblyGroupSignil gAssemblyGroupSignil, IGGlobalSettingsSignil gGlobalSettingsSignil, IGSolutionSignil gSolutionSignil, IGGenerateProgramProgress gGenerateProgramProgress, IPersistence<IInsertResultsAbstract> persistence, IPickAndSave<IInsertResultsAbstract> pickAndSave, CancellationToken cancellationToken) {
    //   IGGenerateProgramResult gGenerateProgramResult;
    //   //
    //   #region Method timing setup
    //   Stopwatch stopWatch = new Stopwatch(); // ToDo: utilize a much more powerfull and ubiquitous timing and profiling tool than a stopwatch
    //   stopWatch.Start();
    //   #endregion
    //   try {
    //     Func<Task<IGGenerateProgramResult>> run = () => ServiceData.EntryPoints.GenerateProgramAsync(gAssemblyGroupSignil, gGlobalSettingsSignil, gSolutionSignil, gGenerateProgramProgress, persistence, pickAndSave, cancellationToken);
    //     gGenerateProgramResult = await run.Invoke().ConfigureAwait(false);
    //     stopWatch.Stop(); // ToDo: utilize a much more powerfull and ubiquitous timing and profiling tool than a stopwatch
    //                       // ToDo: put the results someplace
    //   }
    //   catch (Exception) { // ToDo: define explicit exceptions to catch and report upon
    //                       // ToDo: catch FileIO.FileNotFound, sometimes the file disappears
    //     throw;
    //   }
    //   finally {
    //     // Dispose of the objects that need disposing
    //     setupResultsPickAndSave.Dispose();
    //     setupResultsPersistence.Dispose();
    //   }
    //   return gGenerateProgramResult;
    // }


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
