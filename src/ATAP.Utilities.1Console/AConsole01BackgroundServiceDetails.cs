

using ATAP.Utilities.ComputerInventory.Hardware;
using ATAP.Utilities.ETW;
using ATAP.Utilities.HostedServices;
using ATAP.Utilities.HostedServices.GenerateProgram;
using ATAP.Utilities.Logging;
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
using System.Diagnostics;
using System.Globalization;
using System.IO;
using System.Reflection;
using System.Resources;
using System.Threading;
using System.Threading.Tasks;
using System.Text;
using System.Linq;
using ComputerInventoryHardwareStaticExtensions = ATAP.Utilities.ComputerInventory.Hardware.StaticExtensions;
using PersistenceStaticExtensions = ATAP.Utilities.Persistence.StaticExtensions;
using GenericHostExtensions = ATAP.Utilities.Extensions.GenericHost.Extensions;
using ConfigurationExtensions = ATAP.Utilities.Extensions.Configuration.Extensions;

namespace ATAP.Utilities.AConsole01 {
  public partial class AConsole01BackgroundService : BackgroundService {

    #region Helper methods to reduce code clutter
    void CheckAndHandleCancellationToken(int checkpointNumber, CancellationToken cancellationToken) {
      // check CancellationToken to see if this task is cancelled
      if (cancellationToken.IsCancellationRequested) {
        logger.LogDebug(debugLocalizer["{0}: Cancellation requested, checkpoint number {1}", "ConsoleMonitorBackgroundService", checkpointNumber.ToString(CultureInfo.CurrentCulture)]);
        cancellationToken.ThrowIfCancellationRequested();
      }
    }
    void CheckAndHandleCancellationToken(string locationMessage, CancellationToken cancellationToken) {
      // check CancellationToken to see if this task is cancelled
      if (cancellationToken.IsCancellationRequested) {
        logger.LogDebug(debugLocalizer["{0}: Cancellation requested, checkpoint number {1}", "ConsoleMonitorBackgroundService", locationMessage]);
        cancellationToken.ThrowIfCancellationRequested();
      }
    }
    // Output a message, wrapped with exception handling
    async Task WriteMessageSafelyAsync(StringBuilder mesg, IConsoleSinkHostedService consoleSinkHostedService, CancellationToken cancellationToken) {
      // check CancellationToken to see if this task is cancelled
      CheckAndHandleCancellationToken("WriteMessageSafelyAsync", cancellationToken);
      var task = await consoleSinkHostedService.WriteMessageAsync(mesg).ConfigureAwait(false);
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
    }

    #region Build and write menu
    /// <summary>
    /// Build a multiline menu from the choices, and send to stdout
    /// </summary>
    /// <param name="mesg"></param>
    /// <param name="choices"></param>
    /// <param name="consoleSinkHostedService"></param>
    /// <param name="uILocalizer"></param>
    /// <param name="exceptionLocalizer"></param>
    /// <param name="cancellationToken"></param>
    /// <returns></returns>
    async Task BuildAndWriteMenu(StringBuilder mesg, IEnumerable<string> choices, IConsoleSinkHostedService consoleSinkHostedService, ResourceManagerStringLocalizer uILocalizer, ResourceManagerStringLocalizer exceptionLocalizer, CancellationToken cancellationToken) {
      // check CancellationToken to see if this task is cancelled
      CheckAndHandleCancellationToken("BuildAndWriteMenu", cancellationToken);
      mesg.Clear();

      foreach (var choice in choices) {
        mesg.Append(choice);
        mesg.Append(Environment.NewLine);
      }
      mesg.Append(uILocalizer["Enter a number for a choice, Ctrl-C to Exit"]);

      #region Write the mesg to stdout
      using (Task task = await WriteMessageSafelyAsync(mesg, consoleSinkHostedService, linkedCancellationToken).ConfigureAwait(false)) {
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
      }
      #endregion

    }
    #endregion
    #endregion

    // Format an instance of ConvertFileSystemToGraphResults for UI presentation
    // // Uses the CurrentCulture, converts File Sizes to UnitsNet.Information types, and DateTimes to ITenso Times
    void BuildConvertFileSystemToGraphResults(StringBuilder mesg, ConvertFileSystemToGraphResult convertFileSystemToGraphResult, Stopwatch? stopwatch) {
      mesg.Clear();
      if (stopwatch != null) {
        mesg.Append(uiLocalizer["Running the function took {0} milliseconds", stopwatch.ElapsedMilliseconds.ToString(CultureInfo.CurrentCulture)]);
        mesg.Append(Environment.NewLine);
      }
      mesg.Append(uiLocalizer["DeepestDirectoryTree: {0}", convertFileSystemToGraphResult.DeepestDirectoryTree]);
      mesg.Append(Environment.NewLine);
      mesg.Append(uiLocalizer["LargestFile: {0}", new UnitsNet.Information(convertFileSystemToGraphResult.LargestFile, UnitsNet.Units.InformationUnit.Byte).ToString(CultureInfo.CurrentCulture)]);
      mesg.Append(Environment.NewLine);
      mesg.Append(uiLocalizer["EarliestDirectoryCreationTime: {0}", convertFileSystemToGraphResult.EarliestDirectoryCreationTime.ToString(CultureInfo.CurrentCulture)]);
      mesg.Append(Environment.NewLine);
      mesg.Append(uiLocalizer["LatestDirectoryCreationTime: {0}", convertFileSystemToGraphResult.LatestDirectoryCreationTime.ToString(CultureInfo.CurrentCulture)]);
      mesg.Append(Environment.NewLine);
      mesg.Append(uiLocalizer["EarliestFileCreationTime: {0}", convertFileSystemToGraphResult.EarliestFileCreationTime]);
      mesg.Append(Environment.NewLine);
      mesg.Append(uiLocalizer["LatestFileCreationTime: {0}", convertFileSystemToGraphResult.LatestFileCreationTime]);
      mesg.Append(Environment.NewLine);
      mesg.Append(uiLocalizer["EarliestFileModificationTime: {0}", convertFileSystemToGraphResult.EarliestFileModificationTime]);
      mesg.Append(Environment.NewLine);
      mesg.Append(uiLocalizer["LatestFileModificationTime: {0}", convertFileSystemToGraphResult.LatestFileModificationTime]);
      mesg.Append(Environment.NewLine);
      mesg.Append(uiLocalizer["Number of AcceptableExceptions: {0}", convertFileSystemToGraphResult.AcceptableExceptions.Count]);
      mesg.Append(Environment.NewLine);
      // List the acceptable Exceptions that occurred
      //ToDo: break out AcceptableExceptions by type
    }


    Func<CancellationToken, Task> ExecuteBackgroundServiceDetails = new Func<CancellationToken, Task>((linkedCancellationToken) => {
      Task task;
      // Create a list of choices
      // ToDo: Get the list from the StringConstants, and localize them 
      choices = new List<string>() { "1. Run ConvertFileSystemToGraphAsyncTask", "2. Subscribe ConsoleOut to ConsoleIn", "2. Unsubscribe ConsoleOut from ConsoleIn" };

      // Subscribe to stdin service
      // Subscribe to consoleSourceHostedService. Run the Func<string,Task> every time ConsoleReadLineAsyncAsObservable() produces aa sequence element
      // ToDo:  Add OnError and OnCompleted handlers
      SubscriptionToConsoleReadLineAsyncAsObservableDisposeHandle = consoleSourceHostedService.ConsoleReadLineAsyncAsObservable().SubscribeAsync<string>(
        // OnNext function:
        (inputString) => stdInLineMonitorAction(inputString),
        // OnError
        (ex) => { return Task.FromException(ex); },
        // OnCompleted
        () => {
          SubscriptionToConsoleReadLineAsyncAsObservableDisposeHandle.Dispose();
          return Task.CompletedTask;
        }
        );
    });

    Action<string> stdInLineMonitorAction = new Action<string>(async (inputLineString) => {

      // check CancellationToken to see if this task is canceled
      CheckAndHandleCancellationToken(1, linkedCancellationToken);
      logger.LogDebug(uiLocalizer["ConsoleMonitorFunc inputLineString = {0}", inputLineString]);
      mesg.Append(uiLocalizer["You selected: {0}", inputLineString]);

      #region Write the mesg to stdout
      using (Task task = await WriteMessageSafelyAsync(mesg, consoleSinkHostedService, linkedCancellationToken).ConfigureAwait(false)) {
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
      }
      #endregion

      mesg.Clear();
      switch (inputLineString) {
        case "1":
          try {
            // ToDo: Get these from the appConfiguration
            var rootString = configurationRoot.GetValue<string>(ConsoleMonitorStringConstants.RootStringConfigRootKey, ConsoleMonitorStringConstants.RootStringDefault);
            var asyncFileReadBlockSize = configurationRoot.GetValue<int>(ConsoleMonitorStringConstants.AsyncFileReadBlockSizeConfigRootKey, int.Parse(ConsoleMonitorStringConstants.AsyncFileReadBlockSizeDefault));  // ToDo: should validate in case the ConsoleMonitorStringConstants assembly is messed up?
            var enableHash = configurationRoot.GetValue<bool>(ConsoleMonitorStringConstants.EnableHashBoolConfigRootKey, bool.Parse(ConsoleMonitorStringConstants.EnableHashBoolConfigRootKeyDefault));  // ToDo: should validate in case the ConsoleMonitorStringConstants assembly is messed up?
            var enableProgress = configurationRoot.GetValue<bool>(ConsoleMonitorStringConstants.EnableProgressBoolConfigRootKey, bool.Parse(ConsoleMonitorStringConstants.EnableProgressBoolDefault));// ToDo: should validate in case the ConsoleMonitorStringConstants assembly is messed up?
            var enablePersistence = configurationRoot.GetValue<bool>(ConsoleMonitorStringConstants.EnablePersistenceBoolConfigRootKey, bool.Parse(ConsoleMonitorStringConstants.EnablePersistenceBoolDefault));// ToDo: should validate in case the ConsoleMonitorStringConstants assembly is messed up?
            var enablePickAndSave = configurationRoot.GetValue<bool>(ConsoleMonitorStringConstants.EnablePickAndSaveBoolConfigRootKey, bool.Parse(ConsoleMonitorStringConstants.EnablePickAndSaveBoolDefault));// ToDo: should validate in case the ConsoleMonitorStringConstants assembly is messed up?
            var temporaryDirectoryBase = configurationRoot.GetValue<string>(ConsoleMonitorStringConstants.TemporaryDirectoryBaseConfigRootKey, ConsoleMonitorStringConstants.TemporaryDirectoryBaseDefault);
            var WithPersistenceNodeFileRelativePath = configurationRoot.GetValue<string>(ConsoleMonitorStringConstants.WithPersistenceNodeFileRelativePathConfigRootKey, ConsoleMonitorStringConstants.WithPersistenceNodeFileRelativePathDefault);
            var WithPersistenceEdgeFileRelativePath = configurationRoot.GetValue<string>(ConsoleMonitorStringConstants.WithPersistenceEdgeFileRelativePathConfigRootKey, ConsoleMonitorStringConstants.WithPersistenceEdgeFileRelativePathDefault);
            var filePathsPersistence = new string[2] { temporaryDirectoryBase + WithPersistenceNodeFileRelativePath, temporaryDirectoryBase + WithPersistenceEdgeFileRelativePath };
            var WithPickAndSaveNodeFileRelativePath = configurationRoot.GetValue<string>(ConsoleMonitorStringConstants.WithPickAndSaveNodeFileRelativePathConfigRootKey, ConsoleMonitorStringConstants.WithPickAndSaveNodeFileRelativePathDefault);
            var filePathsPickAndSave = new string[1] { temporaryDirectoryBase + WithPickAndSaveNodeFileRelativePath };
            mesg.Append(uiLocalizer["Running PartitionInfoEx Extension Function ConvertFileSystemToObjectGraph, on rootString {0} with an asyncFileReadBlockSize of {1} with hashihg enabled: {2} ; progress enabled: {3} ; persistence enabled: {5} ; pickAndSave enabled: {4}", rootString, asyncFileReadBlockSize, enableHash, enableProgress, enablePersistence, enablePickAndSave]);
            if (enablePersistence) {
              mesg.Append(Environment.NewLine);
              mesg.Append(uiLocalizer["  persistence filePaths: {0}", string.Join(",", filePathsPersistence)]);
            }
            if (enablePickAndSave) {
              mesg.Append(Environment.NewLine);
              mesg.Append(uiLocalizer["  pickAndSave filePaths {0}", string.Join(",", filePathsPickAndSave)]);
            }
            if (enableProgress) {
              mesg.Append(Environment.NewLine);
              mesg.Append(uiLocalizer["  progressReporting TBD{0}", "ProgressReportingDataStructureDetails"]);
            }

            #region Write the mesg to stdout
            using (Task task = await WriteMessageSafelyAsync(mesg, consoleSinkHostedService, linkedCancellationToken).ConfigureAwait(false)) {
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
            }
            #endregion
            #region ProgressReporting setup
            ConvertFileSystemToGraphProgress? convertFileSystemToGraphProgress; ;
            if (enableProgress) {
              convertFileSystemToGraphProgress = new ConvertFileSystemToGraphProgress();
            }
            else {
              convertFileSystemToGraphProgress = null;
            }
            #endregion
            #region PersistenceViaFiles setup
            // Ensure the Node and Edge files are empty and can be written to

            // Call the SetupViaFileFuncBuilder here, execute the Func that comes back, with filePaths as the argument
            // ToDo: create a function that will create subdirectories if needed to fulfill path, and use that function when creating the temp fiiles
            //ToDo: add exception handling if the setup function fails
            var setupResultsPersistence = PersistenceStaticExtensions.SetupViaFileFuncBuilder()(new SetupViaFileData(filePathsPersistence));

            // Create an insertFunc that references the local variable setupResults, closing over it
            var insertFunc = new Func<IEnumerable<IEnumerable<object>>, IInsertViaFileResults>((insertData) => {
              int numberOfDatas = insertData.ToArray().Length;
              int numberOfStreamWriters = setupResultsPersistence.StreamWriters.Length;
              for (var i = 0; i < numberOfDatas; i++) {
                foreach (string str in insertData.ToArray()[i]) {
                  //ToDo: add async versions await setupResults.StreamWriters[i].WriteLineAsync(str);
                  //ToDo: exception handling
                  setupResultsPersistence.StreamWriters[i].WriteLine(str);
                }
              }
              return new InsertViaFileResults(true);
            });
            Persistence<IInsertResultsAbstract> persistence = new Persistence<IInsertResultsAbstract>(insertFunc);
            #endregion
            #region PickAndSaveViaFiles setup
            // Ensure the Archived files are empty and can be written to

            // Call the SetupViaFileFuncBuilder here, execute the Func that comes back, with filePaths as the argument
            // ToDo: create a function that will create subdirectories if needed to fulfill path, and use that function when creating the temp fiiles
            var setupResultsPickAndSave = PersistenceStaticExtensions.SetupViaFileFuncBuilder()(new SetupViaFileData(filePathsPickAndSave));
            // Create a pickFunc
            var pickFuncPickAndSave = new Func<object, bool>((objToTest) => {
              return FileIOExtensions.IsArchiveFile(objToTest.ToString()) || FileIOExtensions.IsMailFile(objToTest.ToString());
            });
            // Create an insert Func
            var insertFuncPickAndSave = new Func<IEnumerable<IEnumerable<object>>, IInsertViaFileResults>((insertData) => {
              int numberOfStreamWriters = setupResultsPickAndSave.StreamWriters.Length;
              for (var i = 0; i < numberOfStreamWriters; i++) {
                foreach (string str in insertData.ToArray()[i]) {
                  //ToDo: add async versions await setupResults.StreamWriters[i].WriteLineAsync(str);
                  //ToDo: exception handling
                  // ToDo: Make formatting a parameter
                  setupResultsPickAndSave.StreamWriters[i].WriteLine(str);
                }
              }
              return new InsertViaFileResults(true);
            });
            PickAndSave<IInsertResultsAbstract> pickAndSave = new PickAndSave<IInsertResultsAbstract>(pickFuncPickAndSave, insertFuncPickAndSave);
            #endregion

            ConvertFileSystemToGraphResult convertFileSystemToGraphResult;
            #region Method timing setup
            Stopwatch stopWatch = new Stopwatch(); // ToDo: utilize a much more powerfull and ubiquitious timing and profiling tool than a stopwatch
            stopWatch.Start();
            #endregion
            try {
              Func<Task<ConvertFileSystemToGraphResult>> run = () => ComputerInventoryHardwareStaticExtensions.ConvertFileSystemToGraphAsyncTask(rootString, asyncFileReadBlockSize, enableHash, convertFileSystemToGraphProgress, persistence, pickAndSave, linkedCancellationToken);
              convertFileSystemToGraphResult = await run.Invoke().ConfigureAwait(false);
              stopWatch.Stop(); // ToDo: utilize a much more powerfull and ubiquitious timing and profiling tool than a stopwatch
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
            #region Build the results
            BuildConvertFileSystemToGraphResults(mesg, convertFileSystemToGraphResult, stopWatch);
            #endregion
          }
          catch { }
          finally { }
          break;
        case "2":
          #region define the Func<string,Task> to be executed when the ConsoleSourceHostedService.ConsoleReadLineAsyncAsObservable produces a sequence element
          // This Action closes over the current local variables' values
          Func<string, Task> SimpleEchoToConsoleOutFunc = new Func<string, Task>(async (inputLineString) => {
            #region Write the mesg to stdout
            using (Task task = await WriteMessageSafelyAsync(inputLineString, consoleSinkHostedService, linkedCancellationToken).ConfigureAwait(false)) {
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
            }
            #endregion

          });
          #endregion
          break;
        case "10":
          #region setup a local block for handling this choice
          try {
            var enableHash = configurationRoot.GetValue<bool>(ConsoleMonitorStringConstants.EnableHashBoolConfigRootKey, bool.Parse(ConsoleMonitorStringConstants.EnableHashBoolConfigRootKeyDefault));  // ToDo: should validate in case the ConsoleMonitorStringConstants assembly is messed up?
            var enableProgress = configurationRoot.GetValue<bool>(ConsoleMonitorStringConstants.EnableProgressBoolConfigRootKey, bool.Parse(ConsoleMonitorStringConstants.EnableProgressBoolDefault));// ToDo: should validate in case the ConsoleMonitorStringConstants assembly is messed up?
            var enablePersistence = configurationRoot.GetValue<bool>(ConsoleMonitorStringConstants.EnablePersistenceBoolConfigRootKey, bool.Parse(ConsoleMonitorStringConstants.EnablePersistenceBoolDefault));// ToDo: should validate in case the ConsoleMonitorStringConstants assembly is messed up?
            var enablePickAndSave = configurationRoot.GetValue<bool>(ConsoleMonitorStringConstants.EnablePickAndSaveBoolConfigRootKey, bool.Parse(ConsoleMonitorStringConstants.EnablePickAndSaveBoolDefault));// ToDo: should validate in case the ConsoleMonitorStringConstants assembly is messed up?
            var dBConnectionString = configurationRoot.GetValue<string>(ConsoleMonitorStringConstants.DBConnectionStringConfigRootKey, ConsoleMonitorStringConstants.DBConnectionStringDefault);// ToDo: should validate in case the ConsoleMonitorStringConstants assembly is messed up?
                                                                                                                                                                                                // ToDo: This should be a string representation of a known enumeration of ORMLite DB providers that this service can support
            var dBProvider = configurationRoot.GetValue<string>(ConsoleMonitorStringConstants.DBConnectionStringConfigRootKey, ConsoleMonitorStringConstants.DBConnectionStringDefault);// ToDo: should validate in case the ConsoleMonitorStringConstants assembly is messed up?
            dBProvider = SqlServerOrmLiteDialectProvider.Instance;
            #region ProgressReporting setup
            ConvertFileSystemToGraphProgress? convertFileSystemToGraphProgress;
            if (enableProgress) {
              convertFileSystemToGraphProgress = new ConvertFileSystemToGraphProgress();
            }
            else {
              convertFileSystemToGraphProgress = null;
            }
            #endregion
            #region PersistenceViaIORMsetup
            // Call the SetupViaIORMFuncBuilder here, execute the Func that comes back, with dBConnectionString as the argument
            // Ensure the NNode and Edge Tables for this PartitionInfo are empty and can be written to
            // ToDo: create a function that will create Node and Edge tables if they don't yet exist, and use that function when creating the temp fiiles
            // ToDo: add exception handling if the setup function fails
            var setupResultsPersistence = PersistenceStaticExtensions.SetupViaORMFuncBuilder()(new SetupViaORMData(dBConnectionString, dBProvider, linkedCancellationToken));

            // Create an insertFunc that references the local variable setupResults, closing over it
            var insertFunc = new Func<IEnumerable<IEnumerable<object>>, IInsertViaORMResults>((insertData) => {
              int numberOfDatas = insertData.ToArray().Length;
              int numberOfStreamWriters = setupResultsPersistence.StreamWriters.Length;
              for (var i = 0; i < numberOfDatas; i++) {
                foreach (string str in insertData.ToArray()[i]) {
                  //ToDo: add async versions await setupResults.StreamWriters[i].WriteLineAsync(str);
                  //ToDo: exception handling
                  setupResultsPersistence.Tables[i].SQLCmd(str);
                }
              }
              return new InsertViaORMResults(true);
            });
            Persistence<IInsertResultsAbstract> persistence = new Persistence<IInsertResultsAbstract>(insertFunc);
            #endregion
            #region PickAndSaveViaIORM setup
            // Ensure the Node and Edge files are empty and can be written to

            // Call the SetupViaIORMFuncBuilder here, execute the Func that comes back, with filePaths as the argument
            // ToDo: create a function that will create subdirectories if needed to fulfill path, and use that function when creating the temp fiiles
            var setupResultsPickAndSave = PersistenceStaticExtensions.SetupViaORMFuncBuilder()(new SetupViaORMData(dBConnectionString, dBProvider, linkedCancellationToken));
            // Create a pickFunc
            var pickFuncPickAndSave = new Func<object, bool>((objToTest) => {
              return FileIOExtensions.IsArchiveFile(objToTest.ToString()) || FileIOExtensions.IsMailFile(objToTest.ToString());
            });
            // Create an insert Func
            var insertFuncPickAndSave = new Func<IEnumerable<IEnumerable<object>>, IInsertViaORMResults>((insertData) => {
              //int numberOfStreamWriters = setupResultsPickAndSave.StreamWriters.Length;
              //for (var i = 0; i < numberOfStreamWriters; i++) {
              //  foreach (string str in insertData.ToArray()[i]) {
              //    //ToDo: add async versions await setupResults.StreamWriters[i].WriteLineAsync(str);
              //    //ToDo: exception handling
              //    // ToDo: Make formatting a parameter
              //    setupResultsPickAndSave.StreamWriters[i].WriteLine(str);
              //  }
              //}
              return new InsertViaORMResults(true);
            });
            PickAndSave<IInsertResultsAbstract> pickAndSave = new PickAndSave<IInsertResultsAbstract>(pickFuncPickAndSave, insertFuncPickAndSave);
            #endregion
          }
          // To Catch specific exceptions that might occur
          catch {
          }
          // ToDo: dispose
          finally { }
          #endregion
          break;
        default:
          mesg.Clear();
          mesg.Append(uiLocalizer["InvalidInputDoesNotMatchAvailableChoices {0}", inputLineString]);
          break;
      }

      #region Write the mesg to stdout
      using (Task task = await WriteMessageSafelyAsync(mesg, consoleSinkHostedService, linkedCancellationToken).ConfigureAwait(false)) {
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
      }
      #endregion

      BuildMenu(mesg, choices, linkedCancellationToken);

      #region Write the mesg to stdout
      using (Task task = await WriteMessageSafelyAsync(mesg, consoleSinkHostedService, linkedCancellationToken).ConfigureAwait(false)) {
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
      }
      #endregion

    });

  }
}
