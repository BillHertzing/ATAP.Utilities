using ATAP.Utilities.ETW;
using ATAP.Utilities.HostedServices;
using ATAP.Utilities.HostedServices.ConsoleSinkHostedService;
using ATAP.Utilities.HostedServices.ConsoleSourceHostedService;
using ATAP.Utilities.Logging;
using ATAP.Utilities.Reactive;

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
using System.IO;
using System.Text;
using System.Threading;
using System.Threading.Tasks;
using System.Diagnostics;
using System.Globalization;
using System.Linq;
using System.Reactive;
using System.Reactive.Linq;
using FileSystemToObjectGraphService;
using FileSystemGraphToDBService;

namespace ATAP.Utilities.HostedServices.StdInHandlerService {
  public interface IStdInHandlerService {
    Task EnableListeningToStdInAsync();
    Action FinishedWithStdInAction {get;set;}
  }

#if TRACE
  [ETWLogAttribute]
#endif
  public partial class StdInHandlerService : BackgroundService, IDisposable, IStdInHandlerService {
    #region Common Constructor-injected Auto-Implemented Properties and Localizers
    // These properties can only be set in the class constructor.
    // Class constructor for a Hosted Service is called from the GenericHost which injects the DI services referenced in the Constructor Signature
    ILoggerFactory LoggerFactory { get; }
    ILogger<StdInHandlerService> logger { get; }
    IStringLocalizerFactory StringLocalizerFactory { get; }
    IHostEnvironment HostEnvironment { get; }
    IConfiguration HostConfiguration { get; }
    IHostLifetime HostLifetime { get; }
    IConfiguration appConfiguration { get; }
    IHostApplicationLifetime HostApplicationLifetime { get; }
    IStringLocalizer debugLocalizer { get; }
    IStringLocalizer exceptionLocalizer { get; }
    IStringLocalizer uiLocalizer { get; }

    #endregion
    #region Internal and Linked CancellationTokenSource and Tokens
    //CancellationTokenSource internalCancellationTokenSource { get; } = new CancellationTokenSource();
    //CancellationToken internalCancellationToken { get; }
    // Set in the ExecuteAsync method
    //CancellationTokenSource linkedCancellationTokenSource { get; set; }
    // Set in the ExecuteAsync method
    CancellationToken GenericHostsCancellationToken { get; set; }
    #endregion
    #region Constructor-injected fields unique to this service. These represent other DI services used by this service that are expected to be present in the app's DI container, and are constructor-injected
    IFileSystemToObjectGraphService FileSystemToObjectGraphService { get; }
    IFileSystemGraphToDBService FileSystemGraphToDBService { get; }
    IConsoleSinkHostedService consoleSinkHostedService { get; }
    IConsoleSourceHostedService consoleSourceHostedService { get; }
    #endregion
    #region Data for StdInHandlerService
    StdInHandlerServiceData serviceData { get; }
    #endregion
    #region Callback Action for other services when they are ready to release stdIn
    public Action FinishedWithStdInAction { get; set; }

    #endregion
    #region Performance Monitoring data
    Stopwatch Stopwatch { get; }
    #endregion

    #region Constructor
    /// <summary>
    /// Constructor that populates all the injected services provided by a GenericHost, along with the injected services specific to this program that are needed by this HostedService (or derivitive like BackgroundService)
    /// </summary>
    /// <param name="consoleSinkHostedService"></param>
    /// <param name="consoleSourceHostedService"></param>
    /// <param name="loggerFactory"></param>
    /// <param name="hostEnvironment"></param>
    /// <param name="hostConfiguration"></param>
    /// <param name="hostLifetime"></param>
    /// <param name="hostApplicationLifetime"></param>
    public StdInHandlerService(IFileSystemGraphToDBService fileSystemGraphToDBService, IFileSystemToObjectGraphService fileSystemToObjectGraphService, IConsoleSinkHostedService consoleSinkHostedService, IConsoleSourceHostedService consoleSourceHostedService, ILoggerFactory loggerFactory, IStringLocalizerFactory stringLocalizerFactory, IHostEnvironment hostEnvironment, IConfiguration hostConfiguration, IHostLifetime hostLifetime, IConfiguration appConfiguration, IHostApplicationLifetime hostApplicationLifetime) {
      this.StringLocalizerFactory = stringLocalizerFactory ?? throw new ArgumentNullException(nameof(stringLocalizerFactory));
      exceptionLocalizer = stringLocalizerFactory.Create(nameof(AService01.Resources), "AService01");
      debugLocalizer = stringLocalizerFactory.Create(nameof(AService01.Resources), "AService01");
      uiLocalizer = stringLocalizerFactory.Create(nameof(AService01.Resources), "AService01");
      this.LoggerFactory = loggerFactory ?? throw new ArgumentNullException(nameof(loggerFactory));
      this.logger = loggerFactory.CreateLogger<StdInHandlerService>();
      // this.logger = (Logger<AService01StdInHandlerService>) ATAP.Utilities.Logging.LogProvider.GetLogger("AService01StdInHandlerService");
      logger.LogDebug("StdInHandlerService", ".ctor");  // ToDo Fody for tracing constructors, via an optional switch
      this.HostEnvironment = hostEnvironment ?? throw new ArgumentNullException(nameof(hostEnvironment));
      this.HostConfiguration = hostConfiguration ?? throw new ArgumentNullException(nameof(hostConfiguration));
      this.HostLifetime = hostLifetime ?? throw new ArgumentNullException(nameof(hostLifetime));
      this.appConfiguration = appConfiguration ?? throw new ArgumentNullException(nameof(appConfiguration));
      this.HostApplicationLifetime = hostApplicationLifetime ?? throw new ArgumentNullException(nameof(hostApplicationLifetime));
      this.FileSystemGraphToDBService = fileSystemGraphToDBService ?? throw new ArgumentNullException(nameof(fileSystemGraphToDBService));
      this.FileSystemToObjectGraphService = fileSystemToObjectGraphService ?? throw new ArgumentNullException(nameof(fileSystemToObjectGraphService));
      this.consoleSinkHostedService = consoleSinkHostedService ?? throw new ArgumentNullException(nameof(consoleSinkHostedService));
      this.consoleSourceHostedService = consoleSourceHostedService ?? throw new ArgumentNullException(nameof(consoleSourceHostedService));
      //internalCancellationToken = internalCancellationTokenSource.Token;
      Stopwatch = new Stopwatch();
      #region Create the serviceData and initialize it from the StringConstants or this service's ConfigRoot
      this.serviceData = new StdInHandlerServiceData(
        // ToDo: Get the list from the StringConstants, and localize them
        choices: new List<string>() { "1. Run FileSystemToObjectGraphAsyncTask", "2. Run FileSystemGraphToDBAsyncTask", "99: Quit this service" },
        // Create a list of choices
        stdInHandlerState: new StringBuilder(),
        mesg: new StringBuilder());
      FinishedWithStdInAction = () => EnableListeningToStdInAsync();
      #endregion

    }
    #endregion

    #region Helper methods to reduce code clutter
    #region CheckAndHandleCancellationToken
    void CheckAndHandleCancellationToken(int checkpointNumber) {
      // check CancellationToken to see if this task is canceled
      if (GenericHostsCancellationToken.IsCancellationRequested) {
        logger.LogDebug(debugLocalizer["{0}: Cancellation requested, checkpoint number {1}", "StdInHandlerService", checkpointNumber.ToString(CultureInfo.CurrentCulture)]);
        GenericHostsCancellationToken.ThrowIfCancellationRequested();
      }
    }
    void CheckAndHandleCancellationToken(string locationMessage) {
      // check CancellationTokenSource to see if this task is canceled
      if (GenericHostsCancellationToken.IsCancellationRequested) {
        logger.LogDebug(debugLocalizer["{0}: Cancellation requested, checkpoint number {1}", "StdInHandlerService", locationMessage]);
        GenericHostsCancellationToken.ThrowIfCancellationRequested();
      }
    }
    #endregion
    #region WriteMessageSafelyAsync
    // Output a message, wrapped with exception handling
    async Task<Task> WriteMessageSafelyAsync(StringBuilder mesg, IStringLocalizer exceptionLocalizer) {
      // check CancellationToken to see if this task is canceled
      CheckAndHandleCancellationToken("WriteMessageSafelyAsync");
      var task = await consoleSinkHostedService.WriteMessageAsync(mesg).ConfigureAwait(false);
      if (!task.IsCompletedSuccessfully) {
        if (task.IsCanceled) {
          // Ignore if user canceled the operation during a large file output (internal cancellation)
          // re-throw if the cancellation request came from outside the ConsoleMonitor
          /// ToDo: evaluate the linked, inner, and external tokens
          throw new OperationCanceledException();
        }
        else if (task.IsFaulted) {
          //ToDo: Go through the inner exception
          //foreach (var e in t.Exception) {
          //  https://docs.microsoft.com/en-us/dotnet/standard/io/handling-io-errors
          // ToDo figure out what to do if the output stream is closed
          throw new Exception("ToDo: in WriteMessageSafelyAsync");
          //}
        }
      }
      return Task.CompletedTask;
    }
    async Task<Task> WriteMessageSafelyAsync() {
      return await WriteMessageSafelyAsync(serviceData.Mesg, exceptionLocalizer);
    }
    #endregion
    #region Build Menu
    /// <summary>
    /// Build a multi-line menu from the choices, and send to stdout
    /// </summary>
    /// <param name="mesg"></param>
    /// <param name="choices"></param>
    /// <param name="uILocalizer"></param>
    /// <param name="exceptionLocalizer"></param>
    /// <param name="cancellationToken"></param>
    /// <returns></returns>
    void BuildMenu(StringBuilder mesg, IEnumerable<string> choices, IStringLocalizer uILocalizer) {
      // check CancellationToken to see if this task is cancelled
      CheckAndHandleCancellationToken("BuildMenu");
      mesg.Clear();

      foreach (var choice in choices) {
        serviceData.Mesg.Append(uILocalizer[choice]);
        serviceData.Mesg.Append(Environment.NewLine);
      }
      serviceData.Mesg.Append(uiLocalizer["Enter a number for a choice, Ctrl-C to Exit"]);
    }
    void BuildMenu() {
      BuildMenu(serviceData.Mesg, serviceData.Choices, uiLocalizer);
    }
    #endregion
    #region Build and Display Menu
    async Task BuildAndDisplayMenu(StringBuilder mesg, IEnumerable<string> choices, IStringLocalizer uILocalizer, IStringLocalizer exceptionLocalizer) {
      BuildMenu(mesg, choices, uILocalizer);
      await WriteMessageSafelyAsync(mesg, exceptionLocalizer);
    }
    async Task BuildAndDisplayMenu() {
      await BuildAndDisplayMenu(serviceData.Mesg, serviceData.Choices, uiLocalizer, exceptionLocalizer);

    }
    #endregion
    #endregion


    async Task InputLineLoopAsync(string inputLine) {

      int checkpointnumber = 0;
      // check CancellationToken to see if this task is canceled
      CheckAndHandleCancellationToken(checkpointnumber++);

      logger.LogDebug(uiLocalizer["{0} {1} inputLineString = {2}", "StdInHandlerService", "InputLineLoopAsync", inputLine]);
      // Echo to stdOut the line that came in on stdIn
      serviceData.Mesg.Append(uiLocalizer["You selected: {0}", inputLine]);
      #region Write the mesg to stdout
      using (Task task = await WriteMessageSafelyAsync().ConfigureAwait(false)) {
        if (!task.IsCompletedSuccessfully) {
          if (task.IsCanceled) {
            // Ignore if user cancelled the operation during output to stdout (internal cancellation)
            // re-throw if the cancellation request came from outside the stdInLineMonitorAction
            /// ToDo: evaluate the linked, inner, and external tokens
            throw new OperationCanceledException();
          }
          else if (task.IsFaulted) {
            //ToDo: Go through the inner exception
            //foreach (var e in t.Exception) {
            //  https://docs.microsoft.com/en-us/dotnet/standard/io/handling-io-errors
            // ToDo figure out what to do if the output stream is closed
            throw new Exception("ToDo: WriteMessageSafelyAsync returned an AggregateException");
            //}
          }
        }
        serviceData.Mesg.Clear();
      }
      #endregion
      #region Switch on user's selection
      switch (inputLine) {
        case "1":
          // switch stdIn process to FileSystemToObjectGraphService
          FileSystemToObjectGraphService.EnableListeningToStdInAsync(FinishedWithStdInAction);
          serviceData.SubscriptionToConsoleReadLineAsyncAsObservableDisposeHandle.Dispose();
          break;
        case "2":
          // switch stdIn process to FileSystemGraphToDBService
          FileSystemGraphToDBService.EnableListeningToStdInAsync(FinishedWithStdInAction);
          serviceData.SubscriptionToConsoleReadLineAsyncAsObservableDisposeHandle.Dispose();
          break;
        case "99":
          #region Quit the program
          // an instance of IHostApplicationLifetime is constructor-injected primarly to provide access to its StopApplication method
          HostApplicationLifetime.StopApplication();
          #endregion
          break;

        default:
          //serviceData.Mesg.Clear();
          serviceData.Mesg.Append(uiLocalizer["InvalidInput Does Not Match Available Choices: {0}", inputLine]);
          Task.Delay(100000);
          break;
      }
      #endregion
      #region Write the mesg to stdout
      using (Task task = await WriteMessageSafelyAsync().ConfigureAwait(false)) {
        if (!task.IsCompletedSuccessfully) {
          if (task.IsCanceled) {
            // Ignore if user cancelled the operation during output to stdout (internal cancellation)
            // re-throw if the cancellation request came from outside the stdInLineMonitorAction
            /// ToDo: evaluate the linked, inner, and external tokens
            throw new OperationCanceledException();
          }
          else if (task.IsFaulted) {
            //ToDo: Go through the inner exception
            //foreach (var e in t.Exception) {
            //  https://docs.microsoft.com/en-us/dotnet/standard/io/handling-io-errors
            // ToDo figure out what to do if the output stream is closed
            throw new Exception("ToDo: WriteMessageSafelyAsync returned an AggregateException");
            //}
          }
        }
        serviceData.Mesg.Clear();
      }
      #endregion

      #region Build and Display menu
      await BuildAndDisplayMenu();
      #endregion
      #region Write the mesg to stdout
      using (Task task = await WriteMessageSafelyAsync().ConfigureAwait(false)) {
        if (!task.IsCompletedSuccessfully) {
          if (task.IsCanceled) {
            // Ignore if user cancelled the operation during output to stdout (internal cancellation)
            // re-throw if the cancellation request came from outside the stdInLineMonitorAction
            /// ToDo: evaluate the linked, inner, and external tokens
            throw new OperationCanceledException();
          }
          else if (task.IsFaulted) {
            //ToDo: Go through the inner exception
            //foreach (var e in t.Exception) {
            //  https://docs.microsoft.com/en-us/dotnet/standard/io/handling-io-errors
            // ToDo figure out what to do if the output stream is closed
            throw new Exception("ToDo: WriteMessageSafelyAsync returned an AggregateException");
            //}
          }
        }
        serviceData.Mesg.Clear();
      }
      #endregion
    }

    #region ExecuteAsync method as promised by BackgroundService
    protected override async Task ExecuteAsync(CancellationToken genericHostsCancellationToken) {
      genericHostsCancellationToken.ThrowIfCancellationRequested() ;
      #region create linkedCancellationSource and token
      // Combine the cancellation tokens,so that either can stop this HostedService
      //linkedCancellationTokenSource = CancellationTokenSource.CreateLinkedTokenSource(internalCancellationToken, genericHostsCancellationToken);
      GenericHostsCancellationToken = genericHostsCancellationToken;
      #endregion
      #region Register actions with the CancellationToken (s)
      GenericHostsCancellationToken.Register(() => logger.LogDebug(debugLocalizer["{0} {1} genericHostsCancellationToken has signalled stopping."], "StdInHandlerService", "genericHostsCancellationToken"));
      //internalCancellationToken.Register(() => logger.LogDebug(debugLocalizer["{0} {1} internalCancellationToken has signalled stopping."], "StdInHandlerService", "internalCancellationToken"));
      //GenericHostsCancellationToken.Register(() => logger.LogDebug(debugLocalizer["{0} {1} GenericHostsCancellationToken has signalled stopping."], "StdInHandlerService", "GenericHostsCancellationToken"));
      #endregion
      // Register the methods defined in this class with the three CancellationToken properties found on the IHostApplicationLifetime instance passed to this class in it's .ctor
      HostApplicationLifetime.ApplicationStarted.Register(OnStarted);
      HostApplicationLifetime.ApplicationStopping.Register(OnStopping);
      HostApplicationLifetime.ApplicationStopped.Register(OnStopped);


      await EnableListeningToStdInAsync();


    }
    #endregion
    #region StartAsync and StopAsync methods as promised by IHostedService when IHostLifetime is ConsoleLifetime  // ToDo:, see if this is called by service and serviced
    /// <summary>
    /// Called to start the service.
    /// </summary>
    /// <param name="externalCancellationToken"></param> Used to signal FROM the GenericHost TO this BackgroundService a request for cancelllation
    /// <returns></returns>
    public async Task StartAsync(CancellationToken genericHostsCancellationToken) {

      #region create linkedCancellationSource and token
      // Combine the cancellation tokens,so that either can stop this HostedService
      //linkedCancellationTokenSource = CancellationTokenSource.CreateLinkedTokenSource(internalCancellationToken, genericHostsCancellationToken);
      GenericHostsCancellationToken = genericHostsCancellationToken; // linkedCancellationTokenSource.Token;
      #endregion
      #region Register actions with the CancellationToken (s)
      //genericHostsCancellationToken.Register(() => logger.LogDebug(debugLocalizer["{0} {1} genericHostsCancellationToken has signalled stopping."], "StdInHandlerService", "genericHostsCancellationToken"));
      //internalCancellationToken.Register(() => logger.LogDebug(debugLocalizer["{0} {1} internalCancellationToken has signalled stopping."], "StdInHandlerService", "internalCancellationToken"));
      GenericHostsCancellationToken.Register(() => logger.LogDebug(debugLocalizer["{0} {1} GenericHostsCancellationToken has signalled stopping."], "StdInHandlerService", "GenericHostsCancellationToken"));
      #endregion

      await EnableListeningToStdInAsync();

      // Register the methods defined in this class with the three CancellationToken properties found on the IHostApplicationLifetime instance passed to this class in it's .ctor
      HostApplicationLifetime.ApplicationStarted.Register(OnStarted);
      HostApplicationLifetime.ApplicationStopping.Register(OnStopping);
      HostApplicationLifetime.ApplicationStopped.Register(OnStopped);
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

    public override async Task StopAsync(CancellationToken cancellationToken) {
      logger.LogDebug(debugLocalizer["{0} {1}  StopAsync ."], "StdInHandlerService", "StopAsync");
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

    #region 'standard" method for EnableListeningToStdIn
    public async Task EnableListeningToStdInAsync() {
      #region Build and Display Menu
      //await BuildAndDisplayMenu();
      await BuildAndDisplayMenu();
      #endregion

      // Subscribe to consoleSourceHostedService. Run the DoLoopAsync every time ConsoleReadLineAsyncAsObservable() produces a sequence element
      serviceData.SubscriptionToConsoleReadLineAsyncAsObservableDisposeHandle = consoleSourceHostedService.ConsoleReadLineAsyncAsObservable()
            .Subscribe(async
              // OnNext function:
              inputline => {
                try {
                  await InputLineLoopAsync(inputline);
                }
                catch (Exception ex) {

                  throw ex;
                }
              },
              // OnError
              ex => { logger.LogDebug("got an exception"); },
              // OnCompleted
              () => { logger.LogDebug("stdIn completed"); serviceData.SubscriptionToConsoleReadLineAsyncAsObservableDisposeHandle.Dispose(); }
              );
      //return Task.CompletedTask;
    }
    #endregion

    #region IDisposable Support
    private bool disposedValue = false; // To detect redundant calls

    protected virtual void Dispose(bool disposing) {
      if (!disposedValue) {
        if (disposing) {
          if (serviceData != null) {
              serviceData.Dispose();
          }
        }
        disposedValue = true;
      }
    }

    // This code added to correctly implement the disposable pattern.
    public void Dispose() {
      // Do not change this code. Put cleanup code in Dispose(bool disposing) above.
      Dispose(true);
    }
    #endregion

  }
}

//    case "10":
//      #region setup a local block for handling this choice
//      try {
//        var enableHash = configurationRoot.GetValue<bool>(ConsoleMonitorStringConstants.EnableHashBoolConfigRootKey, bool.Parse(ConsoleMonitorStringConstants.EnableHashBoolConfigRootKeyDefault));  // ToDo: should validate in case the ConsoleMonitorStringConstants assembly is messed up?
//        var enableProgress = configurationRoot.GetValue<bool>(ConsoleMonitorStringConstants.EnableProgressBoolConfigRootKey, bool.Parse(ConsoleMonitorStringConstants.EnableProgressBoolDefault));// ToDo: should validate in case the ConsoleMonitorStringConstants assembly is messed up?
//        var enablePersistence = configurationRoot.GetValue<bool>(ConsoleMonitorStringConstants.EnablePersistenceBoolConfigRootKey, bool.Parse(ConsoleMonitorStringConstants.EnablePersistenceBoolDefault));// ToDo: should validate in case the ConsoleMonitorStringConstants assembly is messed up?
//        var enablePickAndSave = configurationRoot.GetValue<bool>(ConsoleMonitorStringConstants.EnablePickAndSaveBoolConfigRootKey, bool.Parse(ConsoleMonitorStringConstants.EnablePickAndSaveBoolDefault));// ToDo: should validate in case the ConsoleMonitorStringConstants assembly is messed up?
//        var dBConnectionString = configurationRoot.GetValue<string>(ConsoleMonitorStringConstants.DBConnectionStringConfigRootKey, ConsoleMonitorStringConstants.DBConnectionStringDefault);// ToDo: should validate in case the ConsoleMonitorStringConstants assembly is messed up?
//                                                                                                                                                                                            // ToDo: This should be a string representation of a known enumeration of ORMLite DB providers that this service can support
//        var dBProvider = configurationRoot.GetValue<string>(ConsoleMonitorStringConstants.DBConnectionStringConfigRootKey, ConsoleMonitorStringConstants.DBConnectionStringDefault);// ToDo: should validate in case the ConsoleMonitorStringConstants assembly is messed up?
//        dBProvider = SqlServerOrmLiteDialectProvider.Instance;
//        #region ProgressReporting setup
//        ConvertFileSystemToGraphProgress? convertFileSystemToGraphProgress;
//        if (enableProgress) {
//          convertFileSystemToGraphProgress = new ConvertFileSystemToGraphProgress();
//        }
//        else {
//          convertFileSystemToGraphProgress = null;
//        }
//        #endregion
//        #region PersistenceViaIORMsetup
//        // Call the SetupViaIORMFuncBuilder here, execute the Func that comes back, with dBConnectionString as the argument
//        // Ensure the NNode and Edge Tables for this PartitionInfo are empty and can be written to
//        // ToDo: create a function that will create Node and Edge tables if they don't yet exist, and use that function when creating the temp fiiles
//        // ToDo: add exception handling if the setup function fails
//        var setupResultsPersistence = PersistenceStaticExtensions.SetupViaORMFuncBuilder()(new SetupViaORMData(dBConnectionString, dBProvider, GenericHostsCancellationToken));

//        // Create an insertFunc that references the local variable setupResults, closing over it
//        var insertFunc = new Func<IEnumerable<IEnumerable<object>>, IInsertViaORMResults>((insertData) => {
//          int numberOfDatas = insertData.ToArray().Length;
//          int numberOfStreamWriters = setupResultsPersistence.StreamWriters.Length;
//          for (var i = 0; i < numberOfDatas; i++) {
//            foreach (string str in insertData.ToArray()[i]) {
//              //ToDo: add async versions await setupResults.StreamWriters[i].WriteLineAsync(str);
//              //ToDo: exception handling
//              setupResultsPersistence.Tables[i].SQLCmd(str);
//            }
//          }
//          return new InsertViaORMResults(true);
//        });
//        Persistence<IInsertResultsAbstract> persistence = new Persistence<IInsertResultsAbstract>(insertFunc);
//        #endregion
//        #region PickAndSaveViaIORM setup
//        // Ensure the Node and Edge files are empty and can be written to

//        // Call the SetupViaIORMFuncBuilder here, execute the Func that comes back, with filePaths as the argument
//        // ToDo: create a function that will create subdirectories if needed to fulfill path, and use that function when creating the temp fiiles
//        var setupResultsPickAndSave = PersistenceStaticExtensions.SetupViaORMFuncBuilder()(new SetupViaORMData(dBConnectionString, dBProvider, GenericHostsCancellationToken));
//        // Create a pickFunc
//        var pickFuncPickAndSave = new Func<object, bool>((objToTest) => {
//          return FileIOExtensions.IsArchiveFile(objToTest.ToString()) || FileIOExtensions.IsMailFile(objToTest.ToString());
//        });
//        // Create an insert Func
//        var insertFuncPickAndSave = new Func<IEnumerable<IEnumerable<object>>, IInsertViaORMResults>((insertData) => {
//          //int numberOfStreamWriters = setupResultsPickAndSave.StreamWriters.Length;
//          //for (var i = 0; i < numberOfStreamWriters; i++) {
//          //  foreach (string str in insertData.ToArray()[i]) {
//          //    //ToDo: add async versions await setupResults.StreamWriters[i].WriteLineAsync(str);
//          //    //ToDo: exception handling
//          //    // ToDo: Make formatting a parameter
//          //    setupResultsPickAndSave.StreamWriters[i].WriteLine(str);
//          //  }
//          //}
//          return new InsertViaORMResults(true);
//        });
//        PickAndSave<IInsertResultsAbstract> pickAndSave = new PickAndSave<IInsertResultsAbstract>(pickFuncPickAndSave, insertFuncPickAndSave);
//        #endregion
//      }
//      // To Catch specific exceptions that might occur
//      catch {
//      }
//      // ToDo: dispose
//      finally { }
//      #endregion
//      break;



//    public static Func<string, StdInHandlerServiceData, Task> DoLoopAsyncBuilder() {
//    Func<string, StdInHandlerServiceData, Task> ret = new Func< string, StdInHandlerServiceData, Task>((inputLine, serviceData) => {
//      int checkpointnumber = 0;
//      // check CancellationToken to see if this task is canceled
//      CheckAndHandleCancellationToken(checkpointnumber++, cancellationTokenSource);
//      return Task.CompletedTask;
//});
//    return ret;
//  }
