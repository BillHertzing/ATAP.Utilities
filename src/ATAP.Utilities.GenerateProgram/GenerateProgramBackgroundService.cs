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

namespace ATAP.Utilities.GenerateProgram {
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
    private readonly IFileWatchersHostedService fileWatchersHostedService;
    #endregion
    #region Data for this Service
    IDisposable SubscriptionToFileWatchersAsObservableDisposeHandle { get; set; }
    #endregion
    /// <summary>
    /// Constructor that populates all the injected services provided by a GenericHost, along with teh injected services specific to this program that are needed by this HostedService (or derivitive like BackgroundService)
    /// </summary>
    /// <param name="fileWatchersHostedService"></param> 
    /// <param name="loggerFactory"></param>
    /// <param name="hostEnvironment"></param>
    /// <param name="hostConfiguration"></param>
    /// <param name="hostLifetime"></param>
    /// <param name="hostApplicationLifetime"></param>
    public GenerateProgramBackgroundService(IFileWatchersHostedService fileWatchersHostedService, ILoggerFactory loggerFactory, IHostEnvironment hostEnvironment, IConfiguration hostConfiguration, IHostLifetime hostLifetime, IHostApplicationLifetime hostApplicationLifetime) {
      this.logger = loggerFactory.CreateLogger<GenerateProgramBackgroundService>();
      //this.stringLocalizer = stringLocalizer ?? throw new ArgumentNullException(nameof(stringLocalizer));;
      this.hostEnvironment = hostEnvironment ?? throw new ArgumentNullException(nameof(hostEnvironment));
      this.hostConfiguration = hostConfiguration ?? throw new ArgumentNullException(nameof(hostConfiguration));
      this.hostLifetime = hostLifetime ?? throw new ArgumentNullException(nameof(hostLifetime));
      this.hostApplicationLifetime = hostApplicationLifetime ?? throw new ArgumentNullException(nameof(hostApplicationLifetime));
      this.fileWatchersHostedService = fileWatchersHostedService ?? throw new ArgumentNullException(nameof(fileWatchersHostedService));
    }

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
      // Create the initialConfigurationBuilder for this genericHost. This creates an ordered chain of configuration providers. The first providers in the chain have the lowest priority, the last providers in the chain have a higher priority.
      //  Initial configuration does not take Environment into account.
      // ToDo: validate this is the best way to find json configuration files from both the installation directory (for installation-wide settings) and from the startup directory
      var loadedFromDirectory = Path.GetDirectoryName(Assembly.GetExecutingAssembly().Location); // ToDo: get it from the hosts configuration
      var initialStartupDirectory = Path.GetDirectoryName(Assembly.GetExecutingAssembly().Location); // ToDo: get it from the hosts configuration
      ConfigurationBuilder generateProgramConfigurationBuilder = new ConfigurationBuilder()
          // Start with a "compiled-in defaults" for anything that is REQUIRED to be provided in configuration for Production
          .AddInMemoryCollection(GenerateProgramDefaultConfiguration.Production)
          // SetBasePath creates a Physical File provider pointing to the directory where this assembly was loaded from
          .SetBasePath(loadedFromDirectory)
          // get any Production level GenerateProgramSettings file present in the installation directory
          .AddJsonFile(StringConstants.generateProgramSettingsFileName + StringConstants.generateProgramSettingsFileNameSuffix, optional: true)
          // and again, SetBasePath creates a Physical File provider, this time pointing to the initial startup directory, which will be used by the following method
          .SetBasePath(initialStartupDirectory)
          // get any Production level GenericHostSettings file  present in the initial startup directory
          .AddJsonFile(StringConstants.generateProgramSettingsFileName + StringConstants.generateProgramSettingsFileNameSuffix, optional: true)
          .AddEnvironmentVariables(prefix: StringConstants.CustomEnvironmentVariablePrefix) // only environment variables that start with the given prefix
                                                                                            ;

      // Create this program's configurationRoot
      var generateProgramConfigurationRoot = generateProgramConfigurationBuilder.Build();

      // Populate the initial ConfigurationRoot

      #endregion
      #region define the Func<string,Task> that will be executed every time the fileWatchersHostedService.ChangedFilesAsObservable produces a sequence element
      // This Action closes over the current local variables' values 
      Func<string, Task> FileWatchersMonitorFunc = new Func<string, Task>(async (changedFilePathString) => {
        int checkpointNumber = 0;
        // check CancellationToken to see if this task is canceled
        CheckAndHandleCancellationToken(++checkpointNumber, linkedCancellationToken);
        logger.LogDebug(string.Format("FileWatchersMonitorFunc changedFilePathString = {0}", changedFilePathString));
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

      // Subscribe to consoleSourceHostedService. Run the Func<string,Task> every time ConsoleReadLineAsyncAsObservable() produces aa sequence element
      // SubscriptionToConsoleReadLineAsObservableDisposeHandle = ConsoleSourceHostedService.ConsoleReadLineAsyncAsObservable().SelectMany(async inputLineString => await GenerateProgramFunc(inputLineString), () => SubscriptionToConsoleReadLineAsObservableDisposeHandle.Dispose()).Subscribe();
      // ToDo:  Add OnError and OnCompleted handlers
      SubscriptionToFileWatchersAsObservableDisposeHandle = fileWatchersHostedService.ChangedFilesAsObservable().SubscribeAsync<string>(FileWatchersMonitorFunc);

      // Wait for the conjoined cancellation token (or individually if the hosted service does not define its own internal cts)
      WaitHandle.WaitAny(new[] { linkedCancellationToken.WaitHandle });
      logger.LogInformation("{ExecuteAsync} GenerateProgramBackgroundService is stopping.");
      SubscriptionToFileWatchersAsObservableDisposeHandle.Dispose();
    }

  }


}
