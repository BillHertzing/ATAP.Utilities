using ATAP.Utilities.ETW;
using ATAP.Utilities.HostedServices;
using ATAP.Utilities.HostedServices.ConsoleSinkHostedService;
using ATAP.Utilities.HostedServices.ConsoleSourceHostedService;

using ATAP.Utilities.Reactive;

using System;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Hosting;
using System.Threading.Tasks;
using Microsoft.Extensions.Localization;
//using ConsoleMonitorStringConstants = ConsoleMonitor.StringConstants;
//using ConsoleMonitorDefaultConfiguration = ConsoleMonitor.DefaultConfiguration;
using System.Threading;
using System.Reactive.Linq;

namespace ATAP.Utilities.HostedServices {
#if TRACE
  [ETWLogAttribute]
#endif
  // A Background service that consumes stdin (Console.In) and acts on the value delivered according to the 
  public class ConsoleMonitorBackgroundService : BackgroundService {
    #region Common Constructor-injected Auto-Implemented Properties
    // These properteis can only be set in the class constructor.
    // Class constructor for a BackgroundService is only called from the GenericHost when DI-injected services are referenced
    ILoggerFactory loggerFactory { get; }
    ILogger<ConsoleMonitorBackgroundService> logger { get; }
    IStringLocalizerFactory stringLocalizerFactory { get; }
    IHostEnvironment hostEnvironment { get; }
    IConfiguration hostConfiguration { get; }
    IHostLifetime hostLifetime { get; }
    IHostApplicationLifetime hostApplicationLifetime { get; }
    #endregion
    #region Internal and Linked CancellationTokenSource and Tokens
    CancellationTokenSource internalCancellationTokenSource { get; } = new CancellationTokenSource();
    CancellationToken internalCancellationToken { get; }
    CancellationTokenSource linkedCancellationTokenSource { get; set; }
    #endregion
    #region Constructor-injected fields unique to this service. These repersent other services expected to bepresent in the app's DI container
    IConsoleSinkHostedService consoleSinkHostedService { get; }
    IConsoleSourceHostedService consoleSourceHostedService { get; }
    #endregion
    #region Data for this Service
    IConfigurationRoot configurationRoot;
    IStringLocalizer debugLocalizer { get; }
    IStringLocalizer exceptionLocalizer { get; }
    private Func<string, Task> consoleMonitorFunc { get;  set; }
    /*
    IEnumerable<string> choices;
    StringBuilder mesg = new StringBuilder();
    IDisposable DisposeThis { get; set; }
    */
    IDisposable SubscriptionToConsoleReadLineAsyncAsObservableDisposeHandle { get; set; }
    //Stopwatch stopWatch; // ToDo: utilize a much more powerfull and ubiquitious timing and profiling tool than a stopwatch

    #endregion
    /// <summary>
    /// Constructor that populates all the injected services provided by a GenericHost, along with teh injected services specific to this program that are needed by this HostedService (or derivitive like BackgroundService)
    /// </summary>
    /// <param name="consoleSinkHostedService"></param>
    /// <param name="consoleSourceHostedService"></param>
    /// <param name="loggerFactory"></param>
    /// <param name="hostEnvironment"></param>
    /// <param name="hostConfiguration"></param>
    /// <param name="hostLifetime"></param>
    /// <param name="hostApplicationLifetime"></param>
    //public ConsoleMonitorBackgroundService(IConsoleSinkHostedService hostedServiceConsoleSink, IConsoleSourceHostedService consoleSourceHostedService, ILoggerFactory loggerFactory, IStringLocalizer stringLocalizer, IHostEnvironment hostEnvironment, IConfiguration hostConfiguration, IHostLifetime hostLifetime, IHostApplicationLifetime hostApplicationLifetime) {
    //public ConsoleMonitorBackgroundService(IConsoleSinkHostedService hostedServiceConsoleSink, IConsoleSourceHostedService consoleSourceHostedService, ILoggerFactory loggerFactory, IStringLocalizerFactory stringLocalizerFactory, IHostEnvironment hostEnvironment, IConfiguration hostConfiguration, IHostLifetime hostLifetime, IHostApplicationLifetime hostApplicationLifetime) {
    public ConsoleMonitorBackgroundService(IConsoleSinkHostedService consoleSinkHostedService, IConsoleSourceHostedService consoleSourceHostedService, ILoggerFactory loggerFactory, IStringLocalizerFactory stringLocalizerFactory, IHostEnvironment hostEnvironment, IConfiguration hostConfiguration, IHostLifetime hostLifetime, IHostApplicationLifetime hostApplicationLifetime) {
      this.stringLocalizerFactory = stringLocalizerFactory ?? throw new ArgumentNullException(nameof(stringLocalizerFactory));
      //this.exceptionLocalizer = stringLocalizerFactory.Create(nameof(Resources.ExceptionResources), "ATAP.Utilities.ConsoleMonitor");
      //this.debugLocalizer = stringLocalizerFactory.Create(nameof(Resources.DebugResources), "ATAP.Utilities.HostedServices");

      this.loggerFactory = loggerFactory ?? throw new ArgumentNullException(nameof(loggerFactory));
      this.logger = loggerFactory.CreateLogger<ConsoleMonitorBackgroundService>();
      this.stringLocalizerFactory = stringLocalizerFactory ?? throw new ArgumentNullException(nameof(stringLocalizerFactory));
      this.hostEnvironment = hostEnvironment ?? throw new ArgumentNullException(nameof(hostEnvironment));
      this.hostConfiguration = hostConfiguration ?? throw new ArgumentNullException(nameof(hostConfiguration));
      this.hostLifetime = hostLifetime ?? throw new ArgumentNullException(nameof(hostLifetime));
      this.hostApplicationLifetime = hostApplicationLifetime ?? throw new ArgumentNullException(nameof(hostApplicationLifetime));
      this.consoleSinkHostedService = consoleSinkHostedService ?? throw new ArgumentNullException(nameof(consoleSinkHostedService));
      this.consoleSourceHostedService = consoleSourceHostedService ?? throw new ArgumentNullException(nameof(consoleSourceHostedService));
      internalCancellationToken = internalCancellationTokenSource.Token;

    }
  
    public void Create(Func<string,Task> consoleMonitorFunc) {
      this.consoleMonitorFunc = consoleMonitorFunc;
    }
    public void Start() {
      // Subscribe to consoleSourceHostedService. Run the Func<string,Task> every time ConsoleReadLineAsyncAsObservable() produces aa sequence element
      // ToDo:  Add OnError and OnCompleted handlers
      SubscriptionToConsoleReadLineAsyncAsObservableDisposeHandle = consoleSourceHostedService.ConsoleReadLineAsyncAsObservable().SubscribeAsync<string>(
        // OnNext function:
        (inputString) => consoleMonitorFunc(inputString)
        // OnError ,
        // OnCompleted
        );
    }
    public void CreateAndStart(Func<string, Task> consoleMonitorFunc) {
      Create(consoleMonitorFunc);
      Start();
    }

    /// <summary>
    /// Called to start the service.
    /// Sets up data structures so that ConsoleMonitors can be handed out
    /// </summary>
    /// <param name="externalCancellationToken"></param>
    /// <returns></returns>
    protected override async Task ExecuteAsync(CancellationToken externalCancellationToken) {

      #region create linkedCancellationSource and token
      // Combine the cancellation tokens,so that either can stop this HostedService
      linkedCancellationTokenSource = CancellationTokenSource.CreateLinkedTokenSource(internalCancellationToken, externalCancellationToken);
      var linkedCancellationToken = linkedCancellationTokenSource.Token;
      #endregion
      #region Register actions with the CancellationToken (s)
      externalCancellationToken.Register(() => logger.LogDebug(debugLocalizer["{0} {1} externalCancellationToken has signalled stopping."], "ConsoleMonitorBackgroundService", "externalCancellationToken"));
      internalCancellationToken.Register(() => logger.LogDebug(debugLocalizer["{0} {1} internalCancellationToken has signalled stopping."], "ConsoleMonitorBackgroundService", "internalCancellationToken"));
      linkedCancellationToken.Register(() => logger.LogDebug(debugLocalizer["{0} {1} linkedCancellationToken has signalled stopping."], "ConsoleMonitorBackgroundService", "linkedCancellationToken"));
      #endregion
      #region Instantiate this service's Data structure
      /*
      #region configurationRoot for this HostedService
      // Create the configurationBuilder for this HostedService. This creates an ordered chain of configuration providers. The first providers in the chain have the lowest priority, the last providers in the chain have a higher priority.
      // The Environment has been configured by the GenericHost before this point is reached
      // InitialStartupDirectory has been set by the GenericHost before this point is reached, and is where the GenericHost program or service was started
      // LoadedFromDirectory has been configured by the GenericHost before this point is reached. It is the location where this assembly resides
      // ToDo: Implement these two values into the GenericHost configurationRoot somehow, then remove from the constructor signature
      var loadedFromDirectory = hostConfiguration.GetValue<string>("SomeStringConstantConfigrootKey", "./"); //ToDo suport dynamic assembly loading form other Startup directories -  Path.GetDirectoryName(Assembly.GetExecutingAssembly().Location);
      var initialStartupDirectory = hostConfiguration.GetValue<string>("SomeStringConstantConfigrootKey", "./");
      // Build the configurationRoot for this service
      var configurationBuilder = ConfigurationExtensions.StandardConfigurationBuilder(loadedFromDirectory, initialStartupDirectory, ConsoleMonitorDefaultConfiguration.Production, ConsoleMonitorStringConstants.SettingsFileName, ConsoleMonitorStringConstants.SettingsFileNameSuffix, StringConstants.CustomEnvironmentVariablePrefix, loggerFactory, stringLocalizerFactory, hostEnvironment, hostConfiguration, linkedCancellationToken);
      configurationRoot = configurationBuilder.Build();
      #endregion
      */
      #endregion
      // Wait for the conjoined cancellation token (or individually if the hosted service does not define its own internal cts)
      WaitHandle.WaitAny(new[] { linkedCancellationToken.WaitHandle });

      logger.LogDebug(debugLocalizer["{0} {1} ConsoleMonitorBackgroundService is stopping due to "], "ConsoleMonitorBackgroundService", "ExecuteAsync"); // add third parameter for internal or external
      SubscriptionToConsoleReadLineAsyncAsObservableDisposeHandle.Dispose();
    }

  }
}
