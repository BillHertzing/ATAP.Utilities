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
  // This file contains the code to be executed in response to each selection by the user from the list of choices
  public partial class Console02BackgroundService : BackgroundService {
    #region Main Input Handling
    async Task DoLoopAsync(string inputLine) {

      // check CancellationToken to see if this task is canceled
      CheckAndHandleCancellationToken(1);

      Logger.LogDebug(DebugLocalizer["{0} {1} inputLineString = {2}"], "Console02BackgroundService", "DoLoopAsync", inputLine);

      // Echo to Console.Out the line that came in on stdIn
      Message.Append(UiLocalizer["You selected: {0}", inputLine]);
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
      #region tempout
      switch (inputLine) {
        case "1":
          // Get these from the Console02 application configuration
          // ToDo: Get these from the database or from a configurationRoot (priority?)
          // ToDo: should validate in case the appStringConstants assembly is messed up?
          // ToDo: should validate in case the ATAP.Services.GenerateCode.StringConstants assembly is messed up?
          // Create the instance of the GInvokeGenerateCodeSignil
          var gInvokeGenerateCodeSignil = GetGInvokeGenerateCodeSignilFromSettings();
      Logger.LogDebug(DebugLocalizer["{0} {1} gInvokeGenerateCodeSignil = {2}"], "Console02BackgroundService", "DoLoopAsync", gInvokeGenerateCodeSignil.ToString());

          Message.Append(UiLocalizer["Running GenerateProgram Function on the AssemblyGroupSignil {0}, with GlobalSettingsKey {1} and SolutionSignilKey {2}", "Console02Mechanical", "ATAPStandardGlobalSettingsKey", "ATAPStandardGSolutionSignilKey"]);

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
                throw new Exception(ExceptionLocalizer[ExceptionLocalizer["ToDo: WriteMessageSafelyAsync returned an AggregateException"]]);
                //}
              }
            }
            Message.Clear();
          }
          #endregion

          #region ProgressReporting setup
          // ToDo: Use the ConsoleMonitor Service to write progress to ConsoleOut
          // Use the ConsoleOut service to report progress, object based
          async void reportToConsoleOut(object progressDataToReport) {
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

          // Create the IProgress object
          IProgress<object>? gGenerateProgramProgress;
          if (gInvokeGenerateCodeSignil.EnableProgress) {
            gGenerateProgramProgress = new Progress<object>(reportToConsoleOut);
          }
          else {
            gGenerateProgramProgress = null;
          }

          // Send first Progress report
          gGenerateProgramProgress.Report("ToDo: localize the first Progress Report message, and any others");
          #endregion

          #region PersistenceViaFiles setup
          // This Console program will persist string data to a single temporary file on the filesystem
          // filePathsPersistence will have one element
          //   the Temporary directory from the appConfiguration, combined with the PersistenceMessageFile from the appConfiguration
          /*
          // Ensure the Message file is empty and can be written to
          // Call the SetupViaFileFuncBuilder here, execute the Func that comes back, with filePaths as the argument
          // ToDo: create a function variation that will create subdirectories if needed to fulfill path, and use that function when creating the temp files
          // ToDo: add exception handling if the setup function fails
          ISetupViaFileResults setupResultsPersistence;
          try {
            setupResultsPersistence = PersistenceStaticExtensions.SetupViaFileFuncBuilder()(new SetupViaFileData(filePathsPersistence));
          }
          catch (System.IO.IOException ex) {
            // prepare message for UI interface
            // ToDo: custom exception,  and include its message here
            Message.Append(UiLocalizer["IOException trying to setup PersistenceViaFiles"]);

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
            // Throw exception, Cancel the entire service (internal CTS), or swallow and Continue (possibly offering hints as to resolution), client's choice
            throw ex;
            // InternalCancellationTokenSource.Signal ????
            // or just continue and let the user make another selection or go fix the problem
            //break;
          }
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
          */

          /*
          #region PickAndSaveViaFiles setup
          // Ensure the Message file is empty and can be written to
          // Call the SetupViaFileFuncBuilder here, execute the Func that comes back, with filePathsPickAndSave as the argument
          // ToDo: create a function that will create subdirectories if needed to fulfill path, and use that function when creating the temp files
          ISetupViaFileResults setupResultsPickAndSave;
          try {
            setupResultsPickAndSave = PersistenceStaticExtensions.SetupViaFileFuncBuilder()(new SetupViaFileData(filePathsPickAndSave));
          }
          catch (System.IO.IOException ex) {
            // prepare message for UI interface
            // ToDo: custom exception,  and include its message here
            Message.Append(UiLocalizer["IOException trying to setup PickAndSaveViaFiles"]);
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
            // Throw exception, Cancel the entire service (internal CTS), or swallow and Continue (possibly offering hints as to resolution), client's choice
            throw ex;
            // InternalCancellationTokenSource.Signal ????
            // or just continue and let the user make another selection or go fix the problem
            //break;
          }
          // Create a pickFunc (AKA Predicate)
          var pickFuncPickAndSave = new Func<object, bool>((objToTest) => {
            return objToTest.ToString() -match "Error";
          });
          // Create an insert Func
          var insertFuncPickAndSave = new Func<IEnumerable<IEnumerable<object>>, IInsertViaFileResults>((insertData) => {
            int numberOfStreamWriters = setupResultsPickAndSave.StreamWriters.Length;
            for (var i = 0; i < numberOfStreamWriters; i++) {
              foreach (string str in insertData.ToArray()[i]) {
                //ToDo: add async versions await setupResults.StreamWriters[i].WriteLineAsync(str);
                //ToDo: exception handling
                // ToDo: Make formatting a parameter
                try {
                  setupResultsPickAndSave.StreamWriters[i].WriteLine(str);
                }
                catch (System.IO.IOException ex) {

                  throw;
                }
              }
            }
            return new InsertViaFileResults(true);
          });
          PickAndSave<IInsertResultsAbstract> pickAndSave = new PickAndSave<IInsertResultsAbstract>(pickFuncPickAndSave, insertFuncPickAndSave);
          #endregion
          */

          IGGenerateProgramResult gGenerateProgramResult;

          #region Method timing setup
          Stopwatch stopWatch = new Stopwatch(); // ToDo: utilize a much more powerfull and ubiquitous timing and profiling tool than a stopwatch
          stopWatch.Start();
          #endregion
          try {
            Func<Task<IGGenerateProgramResult>> run = () => GenerateProgramHostedService.InvokeGenerateProgramAsync(gInvokeGenerateCodeSignil);


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
            /* PickAndSave is not used in the Console02 Background Serveice nor in the GenerateProgram entry points it calls
            setupResultsPickAndSave.Dispose();
            */
            /* Persistence is not used in the Console02 Background Serveice nor in the GenerateProgram entry points it calls
            setupResultsPersistence.Dispose();
            */
          }
          #region Build the results
          BuildGenerateProgramResults(gGenerateProgramResult, stopWatch);
          #endregion

          break;
          case "2" :
        //      #region define the Func<string,Task> to be executed when the ConsoleSourceHostedService.ConsoleReadLineAsyncAsObservable produces a sequence element
        //      // This Action closes over the current local variables' values
        //      Func<string, Task> SimpleEchoToConsoleOutFunc = new Func<string, Task>(async (inputLineString) => {
        //        #region Write the Message to Console.Out
        //        using (Task task = await WriteMessageSafelyAsync(inputLineString, ConsoleSinkHostedService, LinkedCancellationToken).ConfigureAwait(false)) {
        //          if (!task.IsCompletedSuccessfully) {
        //            if (task.IsCanceled) {
        //              // Ignore if user cancelled the operation during output to Console.Out (internal cancellation)
        //              // re-throw if the cancellation request came from outside the stdInLineMonitorAction
        //              /// ToDo: evaluate the linked, inner, and external tokens
        //              throw new OperationCanceledException();
        //            }
        //            else if (task.IsFaulted) {
        //              //ToDo: Go through the inner exception
        //              //foreach (var e in t.Exception) {
        //              //  https://docs.microsoft.com/en-us/dotnet/standard/io/handling-io-errors
        //              // ToDo figure out what to do if the output stream is closed
        //              throw new Exception(ExceptionLocalizer["ToDo: WriteMessageSafelyAsync returned an AggregateException"]);
        //              //}
        //            }
        //          }
        //        }
        //        #endregion

        //      });
        //      #endregion
        //      break;
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
        //        #region PersistenceViaIORMSetup
        //        // Call the SetupViaIORMFuncBuilder here, execute the Func that comes back, with dBConnectionString as the argument
        //        // Ensure the NNode and Edge Tables for this PartitionInfo are empty and can be written to
        //        // ToDo: create a function that will create Node and Edge tables if they don't yet exist, and use that function when creating the temp files
        //        // ToDo: add exception handling if the setup function fails
        //        var setupResultsPersistence = PersistenceStaticExtensions.SetupViaORMFuncBuilder()(new SetupViaORMData(dBConnectionString, dBProvider, LinkedCancellationToken));

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
        //        // ToDo: create a function that will create subdirectories if needed to fulfill path, and use that function when creating the temp files
        //        var setupResultsPickAndSave = PersistenceStaticExtensions.SetupViaORMFuncBuilder()(new SetupViaORMData(dBConnectionString, dBProvider, LinkedCancellationToken));
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
              break;
        case "99":
          #region Quit the program
          //internalcancellationtoken.
          #endregion
          break;

        default:
          Message.Clear();
          Message.Append(UiLocalizer["InvalidInputDoesNotMatchAvailableChoices {0}", inputLine]);
          break;
      }
#endregion
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
      }
      #endregion
      #endregion
      #region presentation of the current Choices to the user after processing last input
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
    }
    #endregion
  }
  #endregion
}
