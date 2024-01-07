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

using ComputerInventoryHardwareStaticExtensions = ATAP.Utilities.ComputerInventory.Hardware.StaticExtensions;
using PersistenceStaticExtensions = ATAP.Utilities.Persistence.Extensions;
using GenericHostExtensions = ATAP.Utilities.GenericHost.Extensions;
using ConfigurationExtensions = ATAP.Utilities.Configuration.Extensions;

using GenericHostStringConstants = AService01.GenericHostStringConstants;
using hostedServiceStringConstants = FileSystemGraphToDBService.StringConstants;

using ServiceStack;

namespace FileSystemGraphToDBService {

  public interface IFileSystemGraphToDBService {

    Task<ConvertFileSystemGraphToDBResults> ConvertFileSystemGraphToDBAsync(string[] filePaths, int asyncFileReadBlockSize, bool enableProgress, IConvertFileSystemGraphToDBProgress fileSystemToGraphToDBProgress);

    Task EnableListeningToStdInAsync(Action finishedWithStdInAction);

  }

#if TRACE
  [ETWLogAttribute]
#endif

  public partial class FileSystemGraphToDBService : IHostedService, IDisposable, IFileSystemGraphToDBService {
    #region Common Constructor-injected Auto-Implemented Properties and Localizers
    // These properties can only be set in the class constructor.
    // Class constructor for a Hosted Service is called from the GenericHost which injects the DI services referenced in the Constructor Signature
    ILoggerFactory loggerFactory { get; }
    ILogger<FileSystemGraphToDBService> logger { get; }
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
    //CancellationTokenSource internalCancellationTokenSource { get; } = new CancellationTokenSource();
    //CancellationToken internalCancellationToken { get; }
    //// Set in the ExecuteAsync method
    //CancellationTokenSource linkedCancellationTokenSource { get; set; }
    // Set in the ExecuteAsync method
    CancellationToken GenericHostsCancellationToken { get; set; }
    #endregion
    #region Constructor-injected fields unique to this service. These represent other DI services used by this service that are expected to be present in the app's DI container, and are constructor-injected
    IConsoleSinkHostedService consoleSinkHostedService { get; }
    IConsoleSourceHostedService consoleSourceHostedService { get; }
    #endregion
    #region Data for Service
    FileSystemGraphToDBServiceData serviceData { get; }
    #endregion
    #region Performance Monitoring data
    Stopwatch Stopwatch { get; } // ToDo: utilize a much more powerfull and ubiquitious timing and profiling tool than a stopwatch
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
    public FileSystemGraphToDBService(IConsoleSinkHostedService consoleSinkHostedService, IConsoleSourceHostedService consoleSourceHostedService, ILoggerFactory loggerFactory, IStringLocalizerFactory stringLocalizerFactory, IHostEnvironment hostEnvironment, IConfiguration hostConfiguration, IHostLifetime hostLifetime, IConfiguration hostedServiceConfiguration, IHostApplicationLifetime hostApplicationLifetime) {
      this.stringLocalizerFactory = stringLocalizerFactory ?? throw new ArgumentNullException(nameof(stringLocalizerFactory));
      exceptionLocalizer = stringLocalizerFactory.Create(nameof(AService01.Resources), "AService01");
      debugLocalizer = stringLocalizerFactory.Create(nameof(AService01.Resources), "AService01");
      uiLocalizer = stringLocalizerFactory.Create(nameof(AService01.Resources), "AService01");
      this.loggerFactory = loggerFactory ?? throw new ArgumentNullException(nameof(loggerFactory));
      this.logger = loggerFactory.CreateLogger<FileSystemGraphToDBService>();
      // this.logger = (Logger<FileSystemGraphToDBService>) ATAP.Utilities.Logging.LogProvider.GetLogger("FileSystemGraphToDBService");
      logger.LogDebug("FileSystemGraphToDBService", ".ctor");  // ToDo Fody for tracing constructors, via an optional switch
      this.hostEnvironment = hostEnvironment ?? throw new ArgumentNullException(nameof(hostEnvironment));
      this.hostConfiguration = hostConfiguration ?? throw new ArgumentNullException(nameof(hostConfiguration));
      this.hostLifetime = hostLifetime ?? throw new ArgumentNullException(nameof(hostLifetime));
      this.hostedServiceConfiguration = hostedServiceConfiguration ?? throw new ArgumentNullException(nameof(hostedServiceConfiguration));
      this.hostApplicationLifetime = hostApplicationLifetime ?? throw new ArgumentNullException(nameof(hostApplicationLifetime));
      this.consoleSinkHostedService = consoleSinkHostedService ?? throw new ArgumentNullException(nameof(consoleSinkHostedService));
      this.consoleSourceHostedService = consoleSourceHostedService ?? throw new ArgumentNullException(nameof(consoleSourceHostedService));
      //internalCancellationToken = internalCancellationTokenSource.Token;
      Stopwatch = new Stopwatch();
      #region Create the serviceData and initialize it from the StringConstants or this service's ConfigRoot
      this.serviceData = new FileSystemGraphToDBServiceData(
        // ToDo: Get the list from the StringConstants, and localize them
        choices: new List<string>() { "1. Run ConvertFileSystemGraphToDBAsyncTask", "2. Changeable", "99: Quit this service" },
        stdInHandlerState: new StringBuilder(),
        mesg: new StringBuilder(),
      convertFileSystemGraphToDBDataAndResults: new ConvertFileSystemGraphToDBDataAndResults(
        convertFileSystemGraphToDBData: new ConvertFileSystemGraphToDBData(
          asyncFileReadBlockSize: hostedServiceConfiguration.GetValue<int>(hostedServiceStringConstants.AsyncFileReadBlockSizeConfigRootKey, int.Parse(hostedServiceStringConstants.AsyncFileReadBlockSizeDefault)),  // ToDo: should validate in case the hostedServiceStringConstants assembly is messed up?
          enableProgress: hostedServiceConfiguration.GetValue<bool>(hostedServiceStringConstants.EnableProgressBoolConfigRootKey, bool.Parse(hostedServiceStringConstants.EnableProgressBoolDefault)), // ToDo: should validate in case the hostedServiceStringConstants assembly is messed up?
          convertFileSystemGraphToDBProgress: new ConvertFileSystemGraphToDBProgress(false),
          temporaryDirectoryBase: hostedServiceConfiguration.GetValue<string>(hostedServiceStringConstants.TemporaryDirectoryBaseConfigRootKey, hostedServiceStringConstants.TemporaryDirectoryBaseDefault),
          nodeFileRelativePath: hostedServiceConfiguration.GetValue<string>(hostedServiceStringConstants.NodeFileRelativePathConfigRootKey, hostedServiceStringConstants.NodeFileRelativePathDefault),
          edgeFileRelativePath: hostedServiceConfiguration.GetValue<string>(hostedServiceStringConstants.EdgeFileRelativePathConfigRootKey, hostedServiceStringConstants.EdgeFileRelativePathDefault),
          filePaths: null,
          dBConnectionString: "",
          ormLiteDialectProviderStringDefault: ""
          ),
        convertFileSystemGraphToDBResults: new ConvertFileSystemGraphToDBResults(
          success: false
        )
        ),
      longRunningTasks: new List<Task<ConvertFileSystemGraphToDBResults>>()
      ) ;
      serviceData.ConvertFileSystemGraphToDBDataAndResults.ConvertFileSystemGraphToDBData.FilePaths = new string[2] {
        serviceData.ConvertFileSystemGraphToDBDataAndResults.ConvertFileSystemGraphToDBData.TemporaryDirectoryBase + serviceData.ConvertFileSystemGraphToDBDataAndResults.ConvertFileSystemGraphToDBData.NodeFileRelativePath,
        serviceData.ConvertFileSystemGraphToDBDataAndResults.ConvertFileSystemGraphToDBData.TemporaryDirectoryBase + serviceData.ConvertFileSystemGraphToDBDataAndResults.ConvertFileSystemGraphToDBData.EdgeFileRelativePath };
      #endregion

    }
    #endregion

   public  async Task<ConvertFileSystemGraphToDBResults> ConvertFileSystemGraphToDBAsync(string[] filePaths, int asyncFileReadBlockSize, bool enableProgress, IConvertFileSystemGraphToDBProgress fileSystemToGraphToDBProgress) {
      #region File Validation and opening
      // Validate the source file(s) exist and are readable
      int numberOfFiles = filePaths.Length;
(FileStream fileStream, StreamWriter streamWriter)[] fileStreamStreamWriterPairs = new (FileStream fileStream, StreamWriter streamWriter)[numberOfFiles]
      for (var i = 0; i < numberOfFiles; i++) {
        try {
fileStreamStreamWriterPairs[i].fileStream = new FileStream(filePathsAsArray[i], FileMode.Create, FileAccess.Write);        }
        catch (System.IO.IOException ex) {
          // ToDo: Better fine-grained exception handling and UI presentation of the error
          serviceData.Mesg.Append(uiLocalizer["IOException opening source files: {0}", ex.Message]);
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
          break;
        }
        try {
          fileStreamStreamWriterPairs[i].streamWriter = new StreamWriter(fileStreamStreamWriterPairs[i].fileStream, Encoding.UTF8);
        }
        catch (System.IO.IOException ex) {
          // ToDo: Dispose the FileStreams
          // ToDo: Better fine-grained exception handling and UI presentation of the error
          serviceData.Mesg.Append(uiLocalizer["IOException opening source files: {0}", ex.Message]);
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
          break;
        }
      }
      #endregion
      /*

#region DBConnection and Table/View validation
#region Database Connection
// Get a scoped DBConnection from the DBConnection DI-injected factory service
#endregion
#region Table/View validation
// Validate the tables needed by this transaction exist in this DB
#endregion
#endregion
#region Structures for Bulk Inserts
// array of SQLInserts to be populated
#endregion
      */
      #region Results data to be returned
      ConvertFileSystemGraphToDBResults convertFileSystemGraphToDBResults = new ConvertFileSystemGraphToDBResults(false);
      #endregion region
      /*
      // Read data
      for (var i = 0; i < numberOfFiles; i++) {
        try {

        //  // Convert to SQL Inserts
        // populate Bulk Array
        // BulkInsert
        }
        catch { }
        finally {
        // Dispose of the objects that need disposing
        }
}
*/
      return convertFileSystemGraphToDBResults;
    }

    #region Helper methods to reduce code clutter
    #region CheckAndHandleCancellationToken
    void CheckAndHandleCancellationToken(int checkpointNumber) {
      // check CancellationToken to see if this task is canceled
      if (GenericHostsCancellationToken.IsCancellationRequested) {
        logger.LogDebug(debugLocalizer["{0}: Cancellation requested, checkpoint number {1}", "FileSystemGraphToDBService", checkpointNumber.ToString(CultureInfo.CurrentCulture)]);
        GenericHostsCancellationToken.ThrowIfCancellationRequested();
      }
    }
    void CheckAndHandleCancellationToken(string locationMessage) {
      // check CancellationTokenSource to see if this task is canceled
      if (GenericHostsCancellationToken.IsCancellationRequested) {
        logger.LogDebug(debugLocalizer["{0}: Cancellation requested, checkpoint location {1}", "FileSystemGraphToDBService", locationMessage]);
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
        mesg.Append(uILocalizer[choice]);
        mesg.Append(Environment.NewLine);
      }
      mesg.Append(uiLocalizer["Enter a number for a choice, Ctrl-C to Exit"]);
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
    #region prepare FileSystemGraphToDBResults for UI Display
    // // Uses the CurrentCulture,
    void PrepareFileSystemGraphToDBResultsForUIStdOut(StringBuilder mesg, IConvertFileSystemGraphToDBResults fileSystemGraphToDBResults, Stopwatch? stopwatch) {
      mesg.Clear();
      if (stopwatch != null) {
        mesg.Append(uiLocalizer["Running the function took {0} milliseconds", stopwatch.ElapsedMilliseconds.ToString(CultureInfo.CurrentCulture)]);
        mesg.Append(Environment.NewLine);
      }
      mesg.Append(uiLocalizer["{0} : {1}{2}", hostedServiceStringConstants.AsyncFileReadBlockSizeConfigRootKey, serviceData.ConvertFileSystemGraphToDBDataAndResults.ConvertFileSystemGraphToDBData.AsyncFileReadBlockSize, Environment.NewLine]);
      mesg.Append(uiLocalizer["{0} : {1}{2}", hostedServiceStringConstants.EnableProgressBoolConfigRootKey, serviceData.ConvertFileSystemGraphToDBDataAndResults.ConvertFileSystemGraphToDBData.EnableProgress, Environment.NewLine]);
      mesg.Append(uiLocalizer["{0} : {1}{2}", hostedServiceStringConstants.TemporaryDirectoryBaseConfigRootKey, serviceData.ConvertFileSystemGraphToDBDataAndResults.ConvertFileSystemGraphToDBData.TemporaryDirectoryBase, Environment.NewLine]);
      mesg.Append(uiLocalizer["{0} : {1}{2}", hostedServiceStringConstants.NodeFileRelativePathConfigRootKey, serviceData.ConvertFileSystemGraphToDBDataAndResults.ConvertFileSystemGraphToDBData.NodeFileRelativePath, Environment.NewLine]);
      mesg.Append(uiLocalizer["{0} : {1}{2}", hostedServiceStringConstants.EdgeFileRelativePathConfigRootKey, serviceData.ConvertFileSystemGraphToDBDataAndResults.ConvertFileSystemGraphToDBData.EdgeFileRelativePath, Environment.NewLine]);
      mesg.Append(uiLocalizer["OverallResult : {0}", fileSystemGraphToDBResults.Success.ToString()]);
      //mesg.Append(uiLocalizer["Number of AcceptableExceptions: {0}", fileSystemGraphToDBResults.AcceptableExceptions.Count]);
      // List the acceptable Exceptions that occurred
      //ToDo: break out AcceptableExceptions by type
    }
    void PrepareFileSystemGraphToDBResultsForUIStdOut() {
      PrepareFileSystemGraphToDBResultsForUIStdOut(serviceData.Mesg, (IConvertFileSystemGraphToDBResults)serviceData, Stopwatch);
    }
    #endregion
    #endregion
    #endregion

    public async Task InputLineLoopAsync(string inputLine) {

      int checkpointnumber = 0;
      // check CancellationToken to see if this task is canceled
      CheckAndHandleCancellationToken(checkpointnumber++);

      logger.LogDebug(uiLocalizer["{0} {1} inputLineString = {2}", "FileSystemGraphToDBService", "InputLineLoopAsync", inputLine]);
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
          if (serviceData.LongRunningTasks.Count > 0) {
            if (true) {
              serviceData.Mesg.Append(uiLocalizer["Task is still running"]);
            } else {
              #region prepare the Results for UI display
              PrepareFileSystemGraphToDBResultsForUIStdOut(serviceData.Mesg, serviceData.ConvertFileSystemGraphToDBDataAndResults.ConvertFileSystemGraphToDBResults, serviceData.ConvertFileSystemGraphToDBDataAndResults.Stopwatch);

              #endregion
            }
          }
          else {
            var task = ConvertFileSystemGraphToDBAsync(
              serviceData.ConvertFileSystemGraphToDBDataAndResults.ConvertFileSystemGraphToDBData.FilePaths,
              serviceData.ConvertFileSystemGraphToDBDataAndResults.ConvertFileSystemGraphToDBData.AsyncFileReadBlockSize,
              serviceData.ConvertFileSystemGraphToDBDataAndResults.ConvertFileSystemGraphToDBData.EnableProgress,
              serviceData.ConvertFileSystemGraphToDBDataAndResults.ConvertFileSystemGraphToDBData.ConvertFileSystemGraphToDBProgress);
            task.ConfigureAwait(false);
            serviceData.LongRunningTasks.Add(task);
            task.Start();
          }
          /*
            if (!task.IsCompletedSuccessfully) {
              if (task.IsCanceled) {
                throw new OperationCanceledException();
              }
              else if (task.IsFaulted) {
                //ToDo: Go through the inner exception
                //foreach (var e in t.Exception) {
                //  https://docs.microsoft.com/en-us/dotnet/standard/io/handling-io-errors
                // ToDo figure out what to do if the operation fails
                throw new Exception("ToDo: ConvertFileSystemGraphToDBAsync returned an AggregateException");
                //}
              }
            }
            else {
              serviceData.ConvertFileSystemGraphToDBDataAndResults.ConvertFileSystemGraphToDBResults = task.Result;
            }
          */
          break;
        case "99":
          #region Quit this service
          // Finished With StdIn
          // Call the callback to notify whoever passed us sdtIn that we are finished with it
          serviceData.FinishedWithStdInAction();
          serviceData.SubscriptionToConsoleReadLineAsyncAsObservableDisposeHandle.Dispose();
          #endregion
          break;
        default:
          serviceData.Mesg.Clear();
          serviceData.Mesg.Append(uiLocalizer["Invalid Input Does Not Match Available Choices: {0}", inputLine]);
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
      GenericHostsCancellationToken.Register(() => logger.LogDebug(debugLocalizer["{0} {1} GenericHostsCancellationToken has signalled stopping."], "FileSystemGraphToDBService", "StartAsync"));
      //internalCancellationToken.Register(() => logger.LogDebug(debugLocalizer["{0} {1} internalCancellationToken has signalled stopping."], "FileSystemGraphToDBService", "StartAsync"));
      //linkedCancellationToken.Register(() => logger.LogDebug(debugLocalizer["{0} {1} GenericHostsCancellationToken has signalled stopping."], "FileSystemGraphToDBService", "StartAsync"));
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
      logger.LogDebug(debugLocalizer["{0} {1}  StopAsync ."], "FileSystemGraphToDBService", "StopAsync");
      //InternalCancellationTokenSource.Cancel();
      // Defer completion promise, until our application has reported it is done.
      // return TaskCompletionSource.Task;
      //Stop(); // would call the servicebase stop if this was a generic hosted service ??
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
    public async Task EnableListeningToStdInAsync(Action finishedWithStdInAction) {
      // Store the callback
      serviceData.FinishedWithStdInAction = finishedWithStdInAction;
      #region Build and Display Menu
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
          // dispose of the SubscriptionToConsoleReadLineAsyncAsObservableDisposeHandle
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
