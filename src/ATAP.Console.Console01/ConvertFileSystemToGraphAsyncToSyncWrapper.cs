using System;
using System.Collections.Generic;
using System.Text;
using System.Threading;
using ATAP.Utilities.ETW;
using System.Threading.Tasks;
using ATAP.Utilities.Persistence;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using ATAP.Utilities.ComputerInventory.Hardware;

namespace ATAP.Utilities.HostedServices
{
//  public class ConvertFileSystemToGraphAsyncToSyncWrapper
//  {
//    IConsoleSinkHostedService consoleSinkHostedService { get; }
//    IConfigurationRoot configurationRoot { get; }
//    // StringConstants StringConstants { get; }
//    StringBuilder mesg { get; }
//    CancellationToken externalCancellationToken { get; }
//    ConvertFileSystemToGraphProgress convertFileSystemToGraphProgress { get; }
//    public Func<string, int, bool, ConvertFileSystemToGraphProgress, Persistence<IInsertResultsAbstract>, PickAndSave<IInsertResultsAbstract>, ConvertFileSystemToGraphResult> Run = new Func<ConvertFileSystemToGraphResult>((rootString, asyncFileReadBlockSize, enableHash, convertFileSystemToGraphProgress, persistence, pickAndSave) =>
//    {

//      // ToDo: Get these from the configRoot in the Data instance in the ConsoleMonitor service
//      var rootString = configurationRoot.GetValue<string>(ConsoleMonitorStringConstants.RootStringConfigRootKey, ConsoleMonitorStringConstants.RootStringDefault);
//      var asyncFileReadBlockSize = configurationRoot.GetValue<int>(ConsoleMonitorStringConstants.AsyncFileReadBlockSizeConfigRootKey, int.Parse(ConsoleMonitorStringConstants.AsyncFileReadBlockSizeDefault));  // ToDo: should validate in case the ConsoleMonitorStringConstants assembly is messed up?

//      var temporaryDirectoryBase = configurationRoot.GetValue<string>(ConsoleMonitorStringConstants.TemporaryDirectoryBaseConfigRootKey, ConsoleMonitorStringConstants.TemporaryDirectoryBaseDefault);
//      var WithPersistenceNodeFileRelativePath = configurationRoot.GetValue<string>(ConsoleMonitorStringConstants.WithPersistenceNodeFileRelativePathConfigRootKey, ConsoleMonitorStringConstants.WithPersistenceNodeFileRelativePathDefault);
//      var WithPersistenceEdgeFileRelativePath = configurationRoot.GetValue<string>(ConsoleMonitorStringConstants.WithPersistenceEdgeFileRelativePathConfigRootKey, ConsoleMonitorStringConstants.WithPersistenceEdgeFileRelativePathDefault);
//      var filePathsPersistence = new string[2] { temporaryDirectoryBase + WithPersistenceNodeFileRelativePath, temporaryDirectoryBase + WithPersistenceEdgeFileRelativePath };
//      var WithPickAndSaveNodeFileRelativePath = configurationRoot.GetValue<string>(ConsoleMonitorStringConstants.WithPickAndSaveNodeFileRelativePathConfigRootKey, ConsoleMonitorStringConstants.WithPickAndSaveNodeFileRelativePathDefault);
//      var filePathsPickAndSave = new string[1] { temporaryDirectoryBase + WithPickAndSaveNodeFileRelativePath };
//      mesg.Append(string.Format("Running PartitionInfoEx Extension Function ConvertFileSystemToObjectGraph, on rootString {0} with an asyncFileReadBlockSize of {1} with hashihg enabled: {2} ; progress enabled: {3} ; persistence enabled: {5} ; pickAndSave enabled: {4}", rootString, asyncFileReadBlockSize, enableHash, enableProgress, enablePersistence, enablePickAndSave));
//      if (enablePersistence)
//      {
//        mesg.Append(Environment.NewLine);
//        mesg.Append(string.Format("  persistence filePaths: {0}", string.Join(",", filePathsPersistence)));
//      }
//      if (enablePickAndSave)
//      {
//        mesg.Append(Environment.NewLine);
//        mesg.Append(string.Format("  pickAndSave filePaths {0}", string.Join(",", filePathsPickAndSave)));
//      }
//      if (enableProgress)
//      {
//        mesg.Append(Environment.NewLine);
//        mesg.Append(string.Format("  progressReporting TBD{0}", "ProgressReportingDataStructureDetails"));
//      }

//      await WriteMessageSafelyAsync(mesg, consoleSinkHostedService, linkedCancellationToken).ConfigureAwait(false); // ToDo: handle Task.Faulted when Console.Out has been closed


//      ConvertFileSystemToGraphResult convertFileSystemToGraphResult;
//      #region Method timing setup
//      Stopwatch stopWatch = new Stopwatch(); // ToDo: utilize a much more powerfull and ubiquitious timing and profiling tool than a stopwatch
//      stopWatch.Start();
//      #endregion
//      try
//      {
//        Func<Task<ConvertFileSystemToGraphResult>> run = () => ComputerInventoryHardwareStaticExtensions.ConvertFileSystemToGraphAsyncTask(rootString, asyncFileReadBlockSize, enableHash, convertFileSystemToGraphProgress, persistence, pickAndSave, linkedCancellationToken);
//        convertFileSystemToGraphResult = await run.Invoke().ConfigureAwait(false);
//        stopWatch.Stop(); // ToDo: utilize a much more powerfull and ubiquitious timing and profiling tool than a stopwatch
//                          // ToDo: put the results someplace
//      }
//      catch (Exception)
//      { // ToDo: define explicit exceptions to catch and report upon
//        // ToDo: catch FileIO.FileNotFound, sometimes the file disappears 
//        throw;
//      }
//      finally
//      {
//        // Dispose of the objects that need disposing
//        setupResultsPickAndSave.Dispose();
//        setupResultsPersistence.Dispose();
//      }
//      #region Build the results
//      BuildConvertFileSystemToGraphResults(mesg, convertFileSystemToGraphResult, stopWatch);
//      #endregion

//      return convertFileSystemToGraphResult;
//    }
//);
//  }
}
