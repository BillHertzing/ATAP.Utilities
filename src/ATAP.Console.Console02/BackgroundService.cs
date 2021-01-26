using ATAP.Utilities.ETW;
using ATAP.Utilities.HostedServices;
using ATAP.Utilities.HostedServices.ConsoleSinkHostedService;
using ATAP.Utilities.HostedServices.ConsoleSourceHostedService;
using ATAP.Utilities.ComputerInventory.Hardware;
using ATAP.Utilities.Logging;
using ATAP.Utilities.Persistence;
using ATAP.Utilities.Philote;
using ATAP.Utilities.Reactive;
using ATAP.Utilities.GenerateProgram;
using ATAP.Services.GenerateCode;
using ATAP.Utilities.Serializer;

using Microsoft.Extensions.Localization;
using Microsoft.Extensions.Options;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Logging.Abstractions;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Hosting.Internal;

using System;
using System.Collections.Generic;
using System.Text;
using System.Threading;
using System.Threading.Tasks;
using System.Diagnostics;
using System.Globalization;
using System.Linq;
using System.Reactive;
using System.Reactive.Linq;

using appStringConstants = ATAP.Console.Console02.StringConstants;
using GenerateProgramServiceStringConstants = ATAP.Services.GenerateCode.StringConstants;
using PersistenceStringConstants = ATAP.Utilities.Persistence.StringConstants;


namespace ATAP.Console.Console02 {
  // This file contains the "boilerplate" code that creates the Background Service
  //#if TRACE
  //  [ETWLogAttribute]
  //#endif
  public partial class Console02BackgroundService : BackgroundService {
    #region Common Constructor-injected Auto-Implemented Properties
    // These properties can only be set in the class constructor.
    // Class constructor for a BackgroundService is called from the GenericHost and the DI-injected services are referenced
    ILoggerFactory LoggerFactory { get; }
    ILogger<Console02BackgroundService> Logger { get; }
    IStringLocalizerFactory StringLocalizerFactory { get; }
    IHostEnvironment HostEnvironment { get; }
    IConfiguration HostConfiguration { get; }
    IHostLifetime HostLifetime { get; }
    IConfiguration AppConfiguration { get; }
    IHostApplicationLifetime HostApplicationLifetime { get; }
    #endregion
    #region Internal and Linked CancellationTokenSource and Tokens
    CancellationTokenSource InternalCancellationTokenSource { get; } = new CancellationTokenSource();
    CancellationToken InternalCancellationToken { get; }
    // Set in the ExecuteAsync method
    CancellationTokenSource LinkedCancellationTokenSource { get; set; }
    // Set in the ExecuteAsync method
    CancellationToken LinkedCancellationToken { get; set; }
    #endregion
    #region Constructor-injected fields unique to this service. These represent other services used by this service that are expected to be present in the app's DI container, and constructor-injected
    IGenerateProgramHostedService GenerateProgramHostedService { get; }
    IConsoleSinkHostedService ConsoleSinkHostedService { get; }
    IConsoleSourceHostedService ConsoleSourceHostedService { get; }
    #endregion
    #region Resource Localizers
    IStringLocalizer DebugLocalizer { get; }
    IStringLocalizer ExceptionLocalizer { get; }
    IStringLocalizer UiLocalizer { get; }
    #endregion
    #region Serializer
    ISerializer Serializer { get; }
    #endregion
    #region Progress
    IProgress<object>? ProgressObject;
    #endregion
    #region Persistence
    ISetupViaFileResults? SetupResultsPersistence;
    string? PersistencePathBase;
    Persistence<IInsertResultsAbstract>? PersistenceObject;
    #endregion
    #region Data for Console02
    IEnumerable<string> Choices;
    StringBuilder Message = new();
    IDisposable SubscriptionToConsoleReadLineAsyncAsObservableDisposeHandle { get; set; }
    Stopwatch stopWatch; // ToDo: utilize a much more powerfull and ubiquitous timing and profiling tool than a stopwatch
    #endregion
    #region Constructor
    /// <summary>
    /// Constructor that populates all the injected services provided by a GenericHost, along with the injected services specific to this program that are needed by this HostedService (or a like BackgroundService)
    /// </summary>
    /// <param name="generateProgramHostedService"></param>
    /// <param name="consoleSinkHostedService"></param>
    /// <param name="consoleSourceHostedService"></param>
    /// <param name="loggerFactory"></param>
    /// <param name="hostEnvironment"></param>
    /// <param name="hostConfiguration"></param>
    /// <param name="hostLifetime"></param>
    /// <param name="hostApplicationLifetime"></param>
    public Console02BackgroundService(IGenerateProgramHostedService generateProgramHostedService, IConsoleSinkHostedService consoleSinkHostedService, IConsoleSourceHostedService consoleSourceHostedService, ILoggerFactory loggerFactory, IStringLocalizerFactory stringLocalizerFactory, IHostEnvironment hostEnvironment, IConfiguration hostConfiguration, IHostLifetime hostLifetime, IConfiguration appConfiguration, IHostApplicationLifetime hostApplicationLifetime, ISerializer serializer) {
      StringLocalizerFactory = stringLocalizerFactory ?? throw new ArgumentNullException(nameof(stringLocalizerFactory));
      ExceptionLocalizer = stringLocalizerFactory.Create("ATAP.Console.Console2.ExceptionResources", "ATAP.Console.Console02");
      DebugLocalizer = stringLocalizerFactory.Create(nameof(ATAP.Console.Console2.DebugResources), "ATAP.Console.Console02");
      UiLocalizer = stringLocalizerFactory.Create(nameof(ATAP.Console.Console2.UIResources), "ATAP.Console.Console02");
      LoggerFactory = loggerFactory ?? throw new ArgumentNullException(nameof(loggerFactory));
      // Logger = (Logger<Console02BackgroundService>) ATAP.Utilities.Logging.LogProvider.GetLogger("Console02BackgroundService");
      Logger = LoggerFactory.CreateLogger<Console02BackgroundService>();
      Logger.LogDebug(DebugLocalizer["{0} {1}: Starting"], "Console02BackgroundService", ".ctor");  // ToDo Fody for tracing constructors, via an optional switch
      HostEnvironment = hostEnvironment ?? throw new ArgumentNullException(nameof(hostEnvironment));
      HostConfiguration = hostConfiguration ?? throw new ArgumentNullException(nameof(hostConfiguration));
      HostLifetime = hostLifetime ?? throw new ArgumentNullException(nameof(hostLifetime));
      AppConfiguration = appConfiguration ?? throw new ArgumentNullException(nameof(appConfiguration));
      HostApplicationLifetime = hostApplicationLifetime ?? throw new ArgumentNullException(nameof(hostApplicationLifetime));
      Serializer = serializer ?? throw new ArgumentNullException(nameof(serializer));
      GenerateProgramHostedService = generateProgramHostedService ?? throw new ArgumentNullException(nameof(generateProgramHostedService));
      ConsoleSinkHostedService = consoleSinkHostedService ?? throw new ArgumentNullException(nameof(consoleSinkHostedService));
      ConsoleSourceHostedService = consoleSourceHostedService ?? throw new ArgumentNullException(nameof(consoleSourceHostedService));
      InternalCancellationToken = InternalCancellationTokenSource.Token;
    }
    #endregion

    #region Helper methods to reduce code clutter
    #region CheckAndHandleCancellationToken
    void CheckAndHandleCancellationToken(int checkpointNumber) {
      // check CancellationToken to see if this task is cancelled
      if (LinkedCancellationTokenSource.IsCancellationRequested) {
        Logger.LogDebug(DebugLocalizer["{0}: Cancellation requested, checkpoint number {1}", "ConsoleMonitorBackgroundService", checkpointNumber.ToString(CultureInfo.CurrentCulture)]);
        LinkedCancellationToken.ThrowIfCancellationRequested();
      }
    }
    void CheckAndHandleCancellationToken(string locationMessage) {
      // check CancellationToken to see if this task is cancelled
      if (LinkedCancellationTokenSource.IsCancellationRequested) {
        Logger.LogDebug(DebugLocalizer["{0}: Cancellation requested, checkpoint number {1}", "ConsoleMonitorBackgroundService", locationMessage]);
        LinkedCancellationToken.ThrowIfCancellationRequested();
      }
    }
    #endregion
    #region WriteMessageSafelyAsync
    // Output the Message to Console.Out, wrapped with exception handling and cancellationToken checking
    async Task<Task> WriteMessageSafelyAsync() {
      // check CancellationToken to see if this task is cancelled
      CheckAndHandleCancellationToken("WriteMessageSafelyAsync");
      var task = await ConsoleSinkHostedService.WriteMessageAsync(Message).ConfigureAwait(false);
      if (!task.IsCompletedSuccessfully) {
        if (task.IsCanceled) {
          // Ignore if user cancelled the operation during a large file output (internal cancellation)
          // re-throw if the cancellation request came from outside the ConsoleMonitor
          /// ToDo: evaluate the linked, inner, and external tokens
          throw new OperationCanceledException();
        }
        else if (task.IsFaulted) {
          //ToDo: Go through the innere exception
          //foreach (var e in t.Exception) {
          //  https://docs.microsoft.com/en-us/dotnet/standard/io/handling-io-errors
          // ToDo figure out what to do if the output stream is closed
          throw new Exception("ToDo: in WriteMessageSafelyAsync");
          //}
        }
      }
      return Task.CompletedTask;
    }
    #endregion
    #region Build and write menu
    /// <summary>
    /// Build a multiline menu from the Choices property into the Message Property
    /// </summary>
    /// <returns>void</returns>
    void BuildMenu() {
      // check CancellationToken to see if this task is cancelled
      CheckAndHandleCancellationToken("BuildAndWriteMenu");
      Message.Clear();
      foreach (var choice in Choices) {
        Message.Append(choice);
        Message.Append(Environment.NewLine);
      }
      Message.Append(UiLocalizer["Enter a number for a choice, Ctrl-C to Exit"]);

    }
    #endregion
    #region PrettyPrintIGGenerateProgramResult
    // Format an instance of GenerateProgramResults for UI presentation
    // // Uses the CurrentCulture
    void BuildGenerateProgramResults(IGGenerateProgramResult gGenerateProgramResult, Stopwatch? stopwatch) {
      Message.Clear();
      if (stopwatch != null) {
        Message.Append(UiLocalizer["Running the function took {0} milliseconds", stopwatch.ElapsedMilliseconds.ToString(CultureInfo.CurrentCulture)]);
        Message.Append(Environment.NewLine);
      }
      Message.Append(UiLocalizer["DB extraction was successful: {0}", gGenerateProgramResult.DBExtractionSuccess.ToString(CultureInfo.CurrentCulture)]);
      Message.Append(Environment.NewLine);
      Message.Append(UiLocalizer["Build was successful: {0}", gGenerateProgramResult.BuildSuccess.ToString(CultureInfo.CurrentCulture)]);
      Message.Append(Environment.NewLine);
      Message.Append(UiLocalizer["Unit Tests were successful: {0}", gGenerateProgramResult.UnitTestsSuccess.ToString(CultureInfo.CurrentCulture)]);
      Message.Append(Environment.NewLine);
      Message.Append(UiLocalizer["Unit Tests coverage was: {0}", gGenerateProgramResult.UnitTestsCoverage.ToString(CultureInfo.CurrentCulture)]);
      Message.Append(Environment.NewLine);
      Message.Append(UiLocalizer["Generated Solution File Directory: {0}", gGenerateProgramResult.GeneratedSolutionFileDirectory.ToString(CultureInfo.CurrentCulture)]);
      Message.Append(Environment.NewLine);
      foreach (var assemblyBuilt in gGenerateProgramResult.CollectionOfAssembliesBuilt) {
        // ToDo: display the container and its contents, staarting with its Name and ID,
        // ToDo: declare and implement ToString for the IPhilote<T> interface that accepts a CultureInfo argument
        Message.Append(UiLocalizer["Assembly Built: {0} {1}", assemblyBuilt.Value.GName.ToString(CultureInfo.CurrentCulture), assemblyBuilt.Key.ID.ToString()]);
        Message.Append(Environment.NewLine);
      }
      Message.Append(UiLocalizer["Packaging was successful: {0}", gGenerateProgramResult.PackagingSuccess.ToString(CultureInfo.CurrentCulture)]);
      Message.Append(UiLocalizer["Deployment was successful: {0}", gGenerateProgramResult.DeploymentSuccess.ToString(CultureInfo.CurrentCulture)]);
      //Message.Append(UiLocalizer["Number of AcceptableExceptions: {0}", gGenerateProgramResult.AcceptableExceptions.Count]);
      Message.Append(Environment.NewLine);
      // List the acceptable Exceptions that occurred
      //ToDo: break out AcceptableExceptions by type
      // ToDo: DBExtraction Details, warnings, and Errors
      // ToDo: Build Details, warnings, and Errors
      // ToDo: Unit Test Details, warnings, and Errors
      // ToDo: Unit Test Coverage Details
      // ToDo: Packaging Details
      // ToDo: Deployment Details
    }
    #endregion

    #region Progress
    async void ReportToConsoleOut(object progressDataToReport) {
      Message.Append(progressDataToReport.ToString());
      #region Write the Message to Console.Out
      using (Task task = await WriteMessageSafelyAsync().ConfigureAwait(false)) {
        if (!task.IsCompletedSuccessfully) {
          if (task.IsCanceled) {
            // Ignore if user cancelled the operation during output to Console.Out (internal cancellation)
            // re-throw if the cancellation request came from outside the stdInLineMonitorAction
            /// ToDo: evaluate the linked, inner, and external tokens
            throw new OperationCanceledException();
          }
          else if (task.IsFaulted) {
            //ToDo: Go through the inner exception
            //foreach (var e in t.Exception) {
            //  https://docs.microsoft.com/en-us/dotnet/standard/io/handling-io-errors
            // ToDo figure out what to do if the output stream is closed
            throw new Exception(message: ExceptionLocalizer["ToDo: WriteMessageSafelyAsync returned an AggregateException"]);
            //}
          }
        }
        Message.Clear();
      }
      #endregion
    }
    #endregion

    #region Signils From Settings
    // Helper methods to read the settings into Signils
    // Helper method to read the settings into an instance of a GInvokeGenerateCodeSignil
    GInvokeGenerateCodeSignil GetGInvokeGenerateCodeSignilFromSettings(IProgress<object>? progress, IPersistence<IInsertResultsAbstract>? persistence) {
      var gInvokeGenerateCodeSignil = new GInvokeGenerateCodeSignil(
        gAssemblyGroupSignil: GetGAssemblyGroupSignilFromSettings()
        , gGlobalSettingsSignil: GetGGlobalSettingsSignilFromSettings()
        , gSolutionSignil: GetGSolutionSignilFromSettings()
        , artifactsDirectoryBase: AppConfiguration.GetValue<string>(GenerateProgramServiceStringConstants.ArtifactsDirectoryBaseConfigRootKey, GenerateProgramServiceStringConstants.ArtifactsDirectoryBaseDefault)
        , artifactsFileRelativePath: AppConfiguration.GetValue<string>(GenerateProgramServiceStringConstants.ArtifactsFileRelativePathConfigRootKey, GenerateProgramServiceStringConstants.ArtifactsFileRelativePathDefault)
        , artifactsFilePaths: default
        , temporaryDirectoryBase: AppConfiguration.GetValue<string>(appStringConstants.TemporaryDirectoryBaseConfigRootKey, appStringConstants.TemporaryDirectoryBaseDefault)
        , enableProgress: AppConfiguration.GetValue<bool>(appStringConstants.EnableProgressConfigRootKey, bool.Parse(appStringConstants.EnableProgressDefault))
        , enablePersistence: AppConfiguration.GetValue<bool>(PersistenceStringConstants.EnablePersistenceConfigRootKey, bool.Parse(PersistenceStringConstants.EnablePersistenceDefault))
        , enablePickAndSave: AppConfiguration.GetValue<bool>(PersistenceStringConstants.EnablePickAndSaveConfigRootKey, bool.Parse(PersistenceStringConstants.EnablePickAndSaveDefault))
        , persistenceMessageFileRelativePath: AppConfiguration.GetValue<string>(GenerateProgramServiceStringConstants.PersistenceMessageFileRelativePathConfigRootKey, GenerateProgramServiceStringConstants.PersistenceMessageFileRelativePathDefault)
        , persistenceFilePaths: default
        , pickAndSaveMessageFileRelativePath: AppConfiguration.GetValue<string>(GenerateProgramServiceStringConstants.PickAndSaveMessageFileRelativePathConfigRootKey, GenerateProgramServiceStringConstants.PickAndSaveMessageFileRelativePathDefault)
        , pickAndSaveFilePaths: default
        , persistence: default
        , pickAndSave: default
        , dBConnectionString: AppConfiguration.GetValue<string>(GenerateProgramServiceStringConstants.DBConnectionStringConfigRootKey, GenerateProgramServiceStringConstants.DBConnectionStringDefault)
        , ormLiteDialectProviderStringDefault: AppConfiguration.GetValue<string>(GenerateProgramServiceStringConstants.OrmLiteDialectProviderConfigRootKey, GenerateProgramServiceStringConstants.OrmLiteDialectProviderDefault)
        , entryPoints: default
      );
      return gInvokeGenerateCodeSignil;
    }

    GAssemblyGroupSignil GetGAssemblyGroupSignilFromSettings() {
      var gAssemblyGroupSignil = new GAssemblyGroupSignil(
      );
      return gAssemblyGroupSignil;
    }
    GGlobalSettingsSignil GetGGlobalSettingsSignilFromSettings() {
      var gGlobalSettingsSignil = new GGlobalSettingsSignil(
      );
      return gGlobalSettingsSignil;
    }
    GSolutionSignil GetGSolutionSignilFromSettings() {
      var gSolutionSettingsSignil = new GSolutionSignil(
      );
      return gSolutionSettingsSignil;
    }
    #endregion
    #endregion

    #region ExecuteAsync, called by the GenericHost StartAsync method, when IHostLifetime is ConsoleLifetime  // ToDo:, see if this is called by service and serviced
    /// <summary>
    /// Called to start the service. This is the main body of the code to execute for this background service
    /// </summary>
    /// <param name="externalCancellationToken"></param> Used to signal FROM the GenericHost TO this BackgroundService a request for cancelllation
    /// <returns></returns>
    protected override async Task ExecuteAsync(CancellationToken externalCancellationToken) {
      #region create linkedCancellationSource and token
      // Combine the cancellation tokens,so that either can stop this HostedService
      LinkedCancellationTokenSource = CancellationTokenSource.CreateLinkedTokenSource(InternalCancellationToken, externalCancellationToken);
      LinkedCancellationToken = LinkedCancellationTokenSource.Token;
      #endregion
      #region Register actions with the CancellationToken (s)
      LinkedCancellationToken.Register(() => Logger.LogDebug(DebugLocalizer["{0} {1} LinkedCancellationToken has signalled stopping."], "Console02BackgroundService", "LinkedCancellationToken"));
      externalCancellationToken.Register(() => Logger.LogDebug(DebugLocalizer["{0} {1} externalCancellationToken has signalled stopping."], "Console02BackgroundService", "externalCancellationToken"));
      InternalCancellationToken.Register(() => {
        Logger.LogDebug(DebugLocalizer["{0} {1} InternalCancellationToken has signalled stopping."], "Console02BackgroundService", "InternalCancellationToken");
        Logger.LogDebug(DebugLocalizer["{0} {1} Need to figure out how to call the parent Console02 and tell it to gracefully shutdown."], "Console02BackgroundService", "InternalCancellationToken");
        //StopAsync()
      });
      #endregion
      #region Define the inputs to respond to
      // Create a list of choices
      Choices = new List<string>() {
         UiLocalizer["1. PrettyPrint a GenerateCodeSignil"]
        , UiLocalizer["2. Roundtrip a GenerateCodeSignil to Settings file and back"]
        , UiLocalizer["3. Run GenerateCodeAsync on a Settings file"]
        , UiLocalizer["99: Quit"]
      };
      #endregion
      #region Initialize Progress
      // Initialize the ProgressObject first time through
      if (ProgressObject == null) { ProgressObject = new Progress<object>(ReportToConsoleOut); }
      #endregion
      #region Initialize Persistence
      // setup the base path of the PersistenceObject
      PersistencePathBase = AppConfiguration.GetValue<string>(appStringConstants.PersistencePathBaseConfigRootKey, appStringConstants.PersistencePathBaseDefault);
      #endregion
      #region initial presentation of the Choices to the user
      // Format the Choices for presentation into Message
      BuildMenu();
      #region Write the Message to Console.Out
      using (Task task = await WriteMessageSafelyAsync().ConfigureAwait(false)) {
        if (!task.IsCompletedSuccessfully) {
          if (task.IsCanceled) {
            // Ignore if user cancelled the operation during output to Console.Out (internal cancellation)
            // re-throw if the cancellation request came from outside the stdInLineMonitorAction
            /// ToDo: evaluate the linked, inner, and external tokens
            throw new OperationCanceledException();
          }
          else if (task.IsFaulted) {
            //ToDo: Go through the inner exception
            //foreach (var e in t.Exception) {
            //  https://docs.microsoft.com/en-us/dotnet/standard/io/handling-io-errors
            // ToDo figure out what to do if the output stream is closed
            throw new Exception(ExceptionLocalizer["ToDo: WriteMessageSafelyAsync returned an AggregateException"]);
            //}
          }
        }
        Message.Clear();
      }
      #endregion
      #endregion
      #region attach to Console.In via the ConsoleSourceHostedService and call DoLoopAsync everytime an input is received
      // Subscribe to ConsoleSourceHostedService. Run the DoLoopAsync every time ConsoleReadLineAsyncAsObservable() produces a sequence element
      SubscriptionToConsoleReadLineAsyncAsObservableDisposeHandle = ConsoleSourceHostedService.ConsoleReadLineAsyncAsObservable()
          .Subscribe(
            // OnNext function:
            inputline => {
              try {
                DoLoopAsync(inputline);
              }
              catch (Exception ex) {

                throw;
              }
            },
            // OnError
            ex => { Logger.LogDebug("got an exception"); },
            // OnCompleted (this happens if the Console.In is closed)
            () => { Logger.LogDebug("stdIn completed"); SubscriptionToConsoleReadLineAsyncAsObservableDisposeHandle.Dispose(); }
            );
      #endregion
    }

    Func<string, Task> stdInLineMonitorAction = new Func<string, Task>(async (inputLineString) => {
      /*


      Logger.LogDebug(DebugLocalizer["{0} {1} Console02BackgroundService is stopping due to "], "Console02BackgroundService", "ExecuteAsync"); // add third parameter for internal or external
      SubscriptionToConsoleReadLineAsyncAsObservableDisposeHandle.Dispose();

    }
    #endregion
          */
    });
    #endregion
  }
}
