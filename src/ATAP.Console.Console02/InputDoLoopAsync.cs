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
using System.IO;
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
using PersistenceStaticExtensions = ATAP.Utilities.Persistence.Extensions;

namespace ATAP.Console.Console02 {
  // This file contains the code to be executed in response to each selection by the user from the list of choices
  public partial class Console02BackgroundService : BackgroundService {
    #region ProgressReporting setup
    // ToDo: Use the ConsoleMonitor Service to write progress to ConsoleOut
    // Use the ConsoleOut service to report progress, object based
    // This async method for reporting progress is shared by all of the Choices
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
      switch (inputLine) {
        case "1":
          Logger.LogDebug(DebugLocalizer["{0} {1}: Both PrettyPrint and Serialize to files multiple GGenerateCode types from declared instances"], "Console02BackgroundService", "DoLoopAsync");
          // Send first Progress report for the user's choice
          ProgressObject!.Report(UiLocalizer["first Progress Report message from input 1"]);
          #region create persistence files and delegate
          // Create PersistenceObject
          var filePathsDictionary = new Dictionary<string, string>() {
            // {"philoteOfTypeInvokeGenerateCodeSignil", PersistencePathBase + "philoteOfTypeInvokeGenerateCodeSignil.json"}
            // , {"gCommentDefault", PersistencePathBase + "gCommentDefault.json" }
            // , {"gCommentWithData", PersistencePathBase + "gCommentWithData.json" }
            // , {"gBodyDefault", PersistencePathBase + "gBodyDefault.json" }
            // , {"gBodyWithData", PersistencePathBase + "gBodyWithData.json" }
            // , {"gProjectUnitDefault", PersistencePathBase + "gProjectUnitDefault.json" }
            // , {"gProjectUnitWithData", PersistencePathBase + "gProjectUnitWithData.json" }
            // , {"gAssemblyUnitDefault", PersistencePathBase + "gAssemblyUnitDefault.json" }
            // , {"gAssemblyUnitWithData", PersistencePathBase + "gAssemblyUnitWithData.json" }
            // , {"gAssemblyGroupSignilDefault", PersistencePathBase + "gAssemblyGroupSignilDefault.json" }
            // , {"gAssemblyGroupSignilWithData", PersistencePathBase + "gAssemblyGroupSignilWithData.json" }
            // , {"gGlobalSettingsSignilFromCodeAsSettings", PersistencePathBase + "gGlobalSettingsSignilFromCode.json"}
            // , {"gSolutionSignilFromCodeAsSettings", PersistencePathBase + "gSolutionSignilFromCode.json"}
            // , {"gInvokeGenerateCodeSignilDefault", PersistencePathBase + "gInvokeGenerateCodeSignilDefault.json"}
             {"gInvokeGenerateCodeSignilWithData", PersistencePathBase + "gInvokeGenerateCodeSignilWithData.json"}
          };
          // Call the SetupViaFileFuncBuilder here, execute the Func that comes back, with filePaths as the argument
          SetupResultsPersistence = ATAP.Utilities.Persistence.Extensions.SetupViaFileFuncBuilder()(new SetupViaFileData(filePathsDictionary));
          // Create an insertFunc that references the property SetupResultsPersistence, closing over it
          var insertFunc = new Func<IDictionary<string, IEnumerable<object>>, IInsertViaFileResults>((insertData) => {
            foreach (var key in insertData.Keys) {
              foreach (var str in insertData[key]) {
                //ToDo: add async versions await setupResults.StreamWriters[i].WriteLineAsync(str);
                //ToDo: exception handling
                SetupResultsPersistence.DictionaryFileStreamStreamWriterPairs[key].streamWriter.WriteLine(str);
              }
            }
            return new InsertViaFileResults(true);
          });
          PersistenceObject = new Persistence<IInsertResultsAbstract>(insertFunc);
          #endregion
          SerializeAndSaveMultipleGGenerateCodeInstances();
          SetupResultsPersistence.Dispose();
          break;
        case "2":
          Logger.LogDebug(DebugLocalizer["{0} {1}: Create multiple GGenerateCode types instances from Settings"], "Console02BackgroundService", "DoLoopAsync");
          // Send first Progress report for the user's choice
          ProgressObject!.Report(UiLocalizer["first Progress Report message from input=2"]);
          // Create SourceReadersObject, using Dictionary, same keys as in output directory

          #region get the json file to read from, use the persistence file from first Choice
          // var WithPersistenceEdgeFileRelativePath = AppConfiguration.GetValue<string>(appStringConstants.WithPersistenceEdgeFileRelativePathConfigRootKey, appStringConstants.WithPersistenceEdgeFileRelativePathDefault);
          // var filePathsPersistence = new string[2] { temporaryDirectoryBase + WithPersistenceNodeFileRelativePath, temporaryDirectoryBase + WithPersistenceEdgeFileRelativePath };

          #endregion
          IGInvokeGenerateCodeSignil gInvokeGenerateCodeSignilFromSettings = GetGInvokeGenerateCodeSignilFromSettings(this.ProgressObject, this.PersistenceObject);
          Logger.LogDebug(DebugLocalizer["{0} {1}: PrettyPrint gInvokeGenerateCodeSignilFromSettings {2}"], "Console02BackgroundService", "DoLoopAsync", Serializer.Serialize(gInvokeGenerateCodeSignilFromSettings));
          break;
        case "3":
          Logger.LogDebug(DebugLocalizer["{0} {1}: Invoke the GenerateCodeService passing it a GInvokeGenerateCodeSignil instance from Settings"], "Console02BackgroundService", "DoLoopAsync");
          // Send first Progress report for the user's choice
          ProgressObject!.Report("UiLocalizer[first Progress Report from input = 3");
          #region Generate Code from Settings in ConfigRoot
          // Get these from the Console02 application configuration
          // ToDo: Get these from the database or from a configurationRoot (priority?)

          // Create the instance of the GInvokeGenerateCodeSignil
          var gInvokeGenerateCodeSignil = GetGInvokeGenerateCodeSignilFromSettings(this.ProgressObject, this.PersistenceObject);
          Logger.LogDebug(DebugLocalizer["{0} {1} gInvokeGenerateCodeSignil = {2}"], "Console02BackgroundService", "DoLoopAsync", Serializer.Serialize(gInvokeGenerateCodeSignil));
          Message.Append(UiLocalizer["Running GenerateProgram Function on the AssemblyGroupSignil {0}, with GlobalSettingsKey {1} and SolutionSignilKey {2}"
          , Serializer.Serialize(gInvokeGenerateCodeSignil.GAssemblyGroupSignil)
          //, Serializer.Serialize(gInvokeGenerateCodeSignil.GGlobalSettingsSignil)
          , Serializer.Serialize(gInvokeGenerateCodeSignil.GSolutionSignil)
           ]);
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

          #region PersistenceViaFiles setup
          // none

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
          */
          #endregion

          #region Method timing setup
          Stopwatch stopWatch = new Stopwatch(); // ToDo: utilize a much more powerfull and ubiquitous timing and profiling tool than a stopwatch
          stopWatch.Start();
          #endregion

          #region Call the service to generate the code
          IGGenerateProgramResult gGenerateProgramResult;
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
            /* PickAndSave is not used in the Console02 Background Service nor in the GenerateProgram entry points it calls
            setupResultsPickAndSave.Dispose();
            */
            /* Persistence is not used in the Console02 Background Service nor in the GenerateProgram entry points it calls
            setupResultsPersistence.Dispose();
            */
          }
          #endregion

          #region Build the results
          BuildGenerateProgramResults(gGenerateProgramResult, stopWatch);
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
                throw new Exception(ExceptionLocalizer[ExceptionLocalizer["ToDo: WriteMessageSafelyAsync returned an AggregateException"]]);
                //}
              }
            }
            Message.Clear();
          }
          #endregion

          #endregion
          #endregion
          break;

        case "99":
          #region Quit the program
          InternalCancellationTokenSource.Cancel();
          #endregion
          break;

        default:
          Message.Clear();
          Message.Append(UiLocalizer["InvalidInputDoesNotMatchAvailableChoices {0}", inputLine]);
          break;
      }

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
      #endregion
    }
    #endregion
  }
}
