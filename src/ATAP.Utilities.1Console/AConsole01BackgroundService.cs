using ATAP.Utilities.HostedServices;
using ATAP.Utilities.ComputerInventory.Hardware;
using ATAP.Utilities.Persistence;

using Microsoft.Extensions.Localization;
using Microsoft.Extensions.Options;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Logging.Abstractions;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Hosting.Internal;
using ILogger = Microsoft.Extensions.Logging.ILogger;

using System;
using System.Collections.Generic;
using System.Text;
using System.Threading;
using System.Threading.Tasks;
using System.Diagnostics;

namespace ATAP.Utilities.AConsole01 {
  // This file contains the "boilerplate" code that creates the Background Service
  public partial class AConsole01BackgroundService : BackgroundService {
    #region Common Constructor-injected Auto-Implemented Properties
    // These properties can only be set in the class constructor.
    // Class constructor for a BackgroundService is called from the GenericHost and the DI-injected services are referenced
    ILoggerFactory loggerFactory { get; }
    ILogger<AConsole01BackgroundService> logger { get; }
    IStringLocalizerFactory stringLocalizerFactory { get; }
    IHostEnvironment hostEnvironment { get; }
    IConfiguration hostConfiguration { get; }
    IHostLifetime hostLifetime { get; }
    IConfiguration appConfiguration { get; }
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
    #region Data for AConsole01
    IStringLocalizer debugLocalizer { get; } 
    IStringLocalizer exceptionLocalizer { get; }
    IStringLocalizer uiLocalizer { get; }

    IEnumerable<string> choices;
    StringBuilder mesg = new StringBuilder();
    IDisposable SubscriptionToConsoleReadLineAsyncAsObservableDisposeHandle { get; set; }
    Stopwatch stopWatch; // ToDo: utilize a much more powerfull and ubiquitious timing and profiling tool than a stopwatch

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
    public AConsole01BackgroundService(IConsoleSinkHostedService consoleSinkHostedService, IConsoleSourceHostedService consoleSourceHostedService, ILoggerFactory loggerFactory, IStringLocalizerFactory stringLocalizerFactory, IHostEnvironment hostEnvironment, IConfiguration hostConfiguration, IHostLifetime hostLifetime, IConfiguration appConfiguration,  IHostApplicationLifetime hostApplicationLifetime) {
      this.stringLocalizerFactory = stringLocalizerFactory ?? throw new ArgumentNullException(nameof(stringLocalizerFactory));
      exceptionLocalizer = stringLocalizerFactory.Create(nameof(Resources), "ATAP.Utilities.AConsole01");
      debugLocalizer = stringLocalizerFactory.Create(nameof(Resources), "ATAP.Utilities.AConsole01");
      uiLocalizer = stringLocalizerFactory.Create(nameof(Resources), "ATAP.Utilities.AConsole01");
      this.loggerFactory = loggerFactory ?? throw new ArgumentNullException(nameof(loggerFactory));
      this.logger = loggerFactory.CreateLogger<AConsole01BackgroundService>();
      this.hostEnvironment = hostEnvironment ?? throw new ArgumentNullException(nameof(hostEnvironment));
      this.hostConfiguration = hostConfiguration ?? throw new ArgumentNullException(nameof(hostConfiguration));
      this.hostLifetime = hostLifetime ?? throw new ArgumentNullException(nameof(hostLifetime));
      this.appConfiguration = appConfiguration ?? throw new ArgumentNullException(nameof(appConfiguration));
      this.hostApplicationLifetime = hostApplicationLifetime ?? throw new ArgumentNullException(nameof(hostApplicationLifetime));
      this.consoleSinkHostedService = consoleSinkHostedService ?? throw new ArgumentNullException(nameof(consoleSinkHostedService));
      this.consoleSourceHostedService = consoleSourceHostedService ?? throw new ArgumentNullException(nameof(consoleSourceHostedService));
      internalCancellationToken = internalCancellationTokenSource.Token;
    }

    /// <summary>
    /// Called to start the service.
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
      externalCancellationToken.Register(() => logger.LogDebug(debugLocalizer["{0} {1} externalCancellationToken has signalled stopping."], "AConsole01BackgroundService", "externalCancellationToken"));
      internalCancellationToken.Register(() => logger.LogDebug(debugLocalizer["{0} {1} internalCancellationToken has signalled stopping."], "AConsole01BackgroundService", "internalCancellationToken"));
      linkedCancellationToken.Register(() => logger.LogDebug(debugLocalizer["{0} {1} linkedCancellationToken has signalled stopping."], "AConsole01BackgroundService", "linkedCancellationToken"));
      #endregion

      // execute the backgroundServiceDetails, break on cancellation or on exception
      try {
        Task task = await ExecuteBackgroundServiceDetails().ConfigureAwait(false);
        // AConsole01 is an inifinte loop, it will never complete successfully
        // Wait for the conjoined cancellation token (or individually if the hosted service does not define its own internal cts)
        WaitHandle.WaitAny(new[] { linkedCancellationToken.WaitHandle });
      }catch (Exception ex){
      }
      logger.LogDebug(debugLocalizer["{0} {1} AConsole01BackgroundService is stopping due to "], "AConsole01BackgroundService", "ExecuteAsync"); // add third parameter for internal or external
      SubscriptionToConsoleReadLineAsyncAsObservableDisposeHandle.Dispose();
    }
  }
}
