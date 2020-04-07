using System;
using System.Collections.Generic;
using System.Text;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using ATAP.Utilities.ETW;
using System.Threading.Tasks;
using Microsoft.Extensions.Localization;
using System.Diagnostics;
using System.Threading;
using ATAP.Utilities.Persistence;
using System.IO;
using System.Linq;
using System.Reactive.Linq;
using ATAP.Utilities.Reactive;
using ATAP.Utilities.HostedServices;

namespace ATAP.Utilities.HostedServices.GenerateProgram {
#if TRACE
  [ETWLogAttribute]
#endif
  // A Function to read stdin (Console) and act on the choices
  public class GenerateProgramBackgroundService : BackgroundService {
    #region Common Constructor-injected fields from the GenericHost
    private readonly ILogger<GenerateProgramBackgroundService> logger;
    private readonly IStringLocalizer<GenerateProgramBackgroundService> stringLocalizer;
    private readonly IHostEnvironment hostEnvironment;
    private readonly IConfiguration hostConfiguration;
    private readonly IHostLifetime hostLifetime;
    private readonly IHostApplicationLifetime hostApplicationLifetime;
    #endregion
    #region Internal and Linked CancellationTokenSource and Tokens
    private readonly CancellationTokenSource internalCancellationTokenSource = new CancellationTokenSource();
    private CancellationToken internalCancellationToken;
    private CancellationTokenSource linkedCancellationTokenSource;
    #endregion
    #region Constructor-injected fields unique to this service
    private readonly IFileSystemWatchersHostedService fileSystemWatchersHostedService;
    // private readonly IFileSystemWatchersAsObservable<GenerateProgramBackgroundService> watcher;
    #endregion
    #region Data for this Service
    IDisposable SubscriptionToFileSystemWatchersAsObservableDisposeHandle { get; set; }
    #endregion
    /// <summary>
    /// Constructor that populates all the injected services provided by a GenericHost, along with this injected services specific to this program that are needed by this HostedService (or derivitive like BackgroundService)
    /// </summary>
    /// <param name="fileSystemWatchersHostedService"></param> 
    /// <param name="loggerFactory"></param>
    /// <param name="hostEnvironment"></param>
    /// <param name="hostConfiguration"></param>
    /// <param name="hostLifetime"></param>
    /// <param name="hostApplicationLifetime"></param>
    // public GenerateProgramBackgroundService(IFileSystemWatchersAsObservableFactoryService fileSystemWatchersAsObservableFactoryService, ILoggerFactory loggerFactory, IHostEnvironment hostEnvironment, IConfiguration hostConfiguration, IHostLifetime hostLifetime, IHostApplicationLifetime hostApplicationLifetime) {
    public GenerateProgramBackgroundService(IFileSystemWatchersHostedService fileSystemWatchersHostedService, ILoggerFactory loggerFactory, IHostEnvironment hostEnvironment, IConfiguration hostConfiguration, IHostLifetime hostLifetime, IHostApplicationLifetime hostApplicationLifetime) {
        this.logger = loggerFactory.CreateLogger<GenerateProgramBackgroundService>();
      //this.stringLocalizer = stringLocalizer ?? throw new ArgumentNullException(nameof(stringLocalizer));;
      this.hostEnvironment = hostEnvironment ?? throw new ArgumentNullException(nameof(hostEnvironment));
      this.hostConfiguration = hostConfiguration ?? throw new ArgumentNullException(nameof(hostConfiguration));
      this.hostLifetime = hostLifetime ?? throw new ArgumentNullException(nameof(hostLifetime));
      this.hostApplicationLifetime = hostApplicationLifetime ?? throw new ArgumentNullException(nameof(hostApplicationLifetime));
      this.fileSystemWatchersHostedService = fileSystemWatchersHostedService ?? throw new ArgumentNullException(nameof(fileSystemWatchersHostedService));
      //if (fileSystemWatchersAsObservableFactoryService == null) { throw new ArgumentNullException(nameof(fileSystemWatchersAsObservableFactoryService)); }
      // this.watcher = fileSystemWatchersAsObservableFactoryService.CreateWatcher<GenerateProgramBackgroundService>();
    }
    #region Startup - things that initialized only once
    public void Startup() {
      // Setup data structures
      // Get a fileSystemWatchersHostedService instance from the injected factory
      var x = 1;
    }
      #endregion
      #region static helper methods to reduce code clutter
      void CheckAndHandleCancellationToken(int checkpointNumber, CancellationToken cancellationToken) {
      // check CancellationToken to see if this task is cancelled
      if (cancellationToken.IsCancellationRequested) {
        // ToDo localize the Log message
        logger.LogDebug($"in ConvertFileSystemToGraphAsyncTask: Cancellation requested, checkpoint number {checkpointNumber}");
        cancellationToken.ThrowIfCancellationRequested();
      }
    }
    #endregion
    protected override async Task ExecuteAsync(CancellationToken externalCancellationToken) {

      #region CancellationToken creation and linking
      // Combine the cancellation tokens,so that either can stop this HostedService
      internalCancellationToken = internalCancellationTokenSource.Token;
      linkedCancellationTokenSource = CancellationTokenSource.CreateLinkedTokenSource(internalCancellationToken, externalCancellationToken);
      var linkedCancellationToken = linkedCancellationTokenSource.Token;
      #endregion
      #region Register actions with the CancellationToken (s)
      externalCancellationToken.Register(() => logger.LogInformation("GenerateProgramBackgroundService: externalCancellationToken has signalled stopping."));
      internalCancellationToken.Register(() => logger.LogInformation("GenerateProgramBackgroundService: internalCancellationToken has signalled stopping."));
      linkedCancellationToken.Register(() => logger.LogInformation("GenerateProgramBackgroundService: linkedCancellationToken has signalled stopping."));
      #endregion
      #region Instantiate this service's Data structure
      #region configurationRoot for this HostedService
      // Create the configurationBuilder for this HostedService. This creates an ordered chain of configuration providers. The first providers in the chain have the lowest priority, the last providers in the chain have a higher priority.
      // The Environment has been configured by the GenericHost before this point is reached
      // Both LoadedFromDirectory and InitialStartupDirectory have been configured by the GenericHost before this point is reached

      var loadedFromDirectory = hostConfiguration.GetValue<string>("SomeStringConstantConfigrootKey", "./"); //ToDo suport dynamic assembly loading form other Startup directories -  Path.GetDirectoryName(Assembly.GetExecutingAssembly().Location);
      var initialStartupDirectory = hostConfiguration.GetValue<string>("SomeStringConstantConfigrootKey", "./");
      // IConfigurationBuilder configurationBuilder = IConfigurationBuilder.Extensions.HostedServiceConfigurationBuilder(hostConfiguration, stringLocalizer, GenerateProgramDefaultConfiguration.Production, StringConstants.GenerateProgramSettingsFileName, StringConstants.GenerateProgramSettingsFileNameSuffix, StringConstants.CustomEnvironmentVariablePrefix);
      IConfigurationBuilder configurationBuilder = new ConfigurationBuilder()
          // Start with a "compiled-in defaults" for anything that is REQUIRED to be provided in configuration for Production
          .AddInMemoryCollection(GenerateProgramDefaultConfiguration.Production)
          // SetBasePath creates a Physical File provider pointing to the directory where this assembly was loaded from
          .SetBasePath(loadedFromDirectory)
          // get any Production level GenerateProgramSettings file present in the installation directory
          // ToDo: File names should be localized
          .AddJsonFile(StringConstants.GenerateProgramSettingsFileName + StringConstants.GenerateProgramSettingsFileNameSuffix, optional: true);
      // Add environment-specific settings file
      if (!hostEnvironment.IsProduction()) {
        configurationBuilder.AddJsonFile(StringConstants.GenerateProgramSettingsFileName + "." + hostEnvironment.EnvironmentName + StringConstants.GenerateProgramSettingsFileNameSuffix, optional: true);
      }
      // and again, SetBasePath creates a Physical File provider, this time pointing to the initial startup directory, which will be used by the following method
      configurationBuilder.SetBasePath(initialStartupDirectory)
          // get any Production level GenericHostSettings file  present in the initial startup directory
          .AddJsonFile(StringConstants.GenerateProgramSettingsFileName + StringConstants.GenerateProgramSettingsFileNameSuffix, optional: true);
      if (!hostEnvironment.IsProduction()) {
        configurationBuilder.AddJsonFile(StringConstants.GenerateProgramSettingsFileName + "." + hostEnvironment.EnvironmentName + StringConstants.GenerateProgramSettingsFileNameSuffix, optional: true);
      }
      // Add environment variables for this HostedService
      // only environment variables that start with the given prefix
      configurationBuilder.AddEnvironmentVariables(prefix: StringConstants.CustomEnvironmentVariablePrefix);
      // Note that command line arguments are available on hostConfig

      // Create configurationRoot for this HostedService
      var generateProgramConfigurationRoot = configurationBuilder.Build();
      #endregion
      #region Filewatchers
      var fileSystemWatcherArgs = new FileSystemWatcherArg[1] { new FileSystemWatcherArg(path: ".") };
      var fileSystemWatchersAsObservable = fileSystemWatchersHostedService.Create(fileSystemWatcherArgs);
      #endregion
      #endregion

      #region define the Func<string,Task> that will be executed every time the fileSystemWatchersHostedService.ChangedFilesAsObservable produces a sequence element
      // This Action closes over the current local variables' values 
      Func<string, Task> FileSystemWatchersMonitorFunc = new Func<string, Task>(async (changedFilePathString) => {
        int checkpointNumber = 0;
        // check CancellationToken to see if this task is canceled
        CheckAndHandleCancellationToken(++checkpointNumber, linkedCancellationToken);
        logger.LogDebug(string.Format("FileSystemWatchersMonitorFunc changedFilePathString = {0}", changedFilePathString));
        // Extract
        // Update the configurationRoot
        // Transform
        // Create the intermediate structures as specified in the configurationRoot
        // Populate the intermediate structures with data from the configurationRoot
        // Break if errors
        // Load
        // write out all specified files
        // Break if errors
        // Build
        // Invoke dotnet build
        // Break if errors
        // Test
        // invoke dotnet test
        // Break if errors
        // Display results
        // Summary:
        // Details
      }
      );
      #endregion

      
      // Wait for the conjoined cancellation token (or individually if the hosted service does not define its own internal cts)
      WaitHandle.WaitAny(new[] { linkedCancellationToken.WaitHandle });
      logger.LogInformation("{ExecuteAsync} GenerateProgramBackgroundService is stopping.");
      SubscriptionToFileSystemWatchersAsObservableDisposeHandle.Dispose();
    }

  }


}
