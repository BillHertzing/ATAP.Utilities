using ATAP.Utilities.ETW;
using ATAP.Utilities.HostedServices;
using ATAP.Utilities.HostedServices.ConsoleSinkHostedService;
using ATAP.Utilities.HostedServices.ConsoleSourceHostedService;
using ATAP.Utilities.ComputerInventory.Hardware;
using ATAP.Utilities.Logging;
using ATAP.Utilities.Persistence;
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
using GenericHostExtensions = ATAP.Utilities.Extensions.GenericHost.Extensions;
using ConfigurationExtensions = ATAP.Utilities.Extensions.Configuration.Extensions;
using appStringConstants = FileSystemToObjectGraphService.StringConstants;

namespace FileSystemToObjectGraphService {

  interface IFileSystemToObjectGraphServiceData : IFileSystemToObjectGraphData, IFileSystemToObjectGraphResults, IFileSystemToObjectGraphProgress, IDisposable {
    ConfigurationRoot ConfigurationRoot { get; }
    IEnumerable<string> Choices { get; }
    StringBuilder Mesg { get; }
    IDisposable SubscriptionToConsoleReadLineAsyncAsObservableDisposeHandle { get; set; }
    StringBuilder StdInHandlerState { get; }
  }

  interface IFileSystemToObjectGraphData {
    string RootString { get; set; }
    int AsyncFileReadBlockSize { get; set; }
    bool EnableHash { get; set; }
    bool EnablePersistence { get; set; }
    bool EnablePickAndSave { get; set; }
    bool EnableProgress { get; set; }
    string TemporaryDirectoryBase { get; set; }
    string PersistenceNodeFileRelativePath { get; set; }
    string PersistenceEdgeFileRelativePath { get; set; }
    string[] PersistenceFilePaths { get; set; }
    string PickAndSaveNodeFileRelativePath { get; set; }
    string PickAndSaveEdgeFileRelativePath { get; set; }
    string[] PickAndSaveFilePaths { get; set; }
    string DBConnectionString { get; }
    string OrmLiteDialectProviderStringDefault { get; }
  }

  interface IFileSystemToObjectGraphResults {
    bool Success { get; set; }
  }

  interface IFileSystemToObjectGraphProgress {

  }


  class FileSystemToObjectGraphServiceData : IFileSystemToObjectGraphServiceData, IDisposable {
    public ConfigurationRoot ConfigurationRoot { get;  }
    public IEnumerable<string> Choices { get;  }
    public StringBuilder StdInHandlerState { get;  }
    public StringBuilder Mesg { get;  }
    public IDisposable SubscriptionToConsoleReadLineAsyncAsObservableDisposeHandle { get; set; }
    public Action FinishedWithStdInAction { get; set; }
  public string RootString { get; set; }
    public int AsyncFileReadBlockSize { get; set; }
    public bool EnableHash { get; set; }
    public bool EnablePersistence { get; set; }
    public bool EnablePickAndSave { get; set; }
    public bool EnableProgress { get; set; }
    public string TemporaryDirectoryBase { get; set; }
    public string PersistenceEdgeFileRelativePath { get; set; }
    public string PersistenceNodeFileRelativePath { get; set; }
    public string[] PersistenceFilePaths { get; set; }
    public string PickAndSaveEdgeFileRelativePath { get; set; }
    public string PickAndSaveNodeFileRelativePath { get; set; }
    public string[] PickAndSaveFilePaths { get; set; }
    public string DBConnectionString { get; set; }
    public string OrmLiteDialectProviderStringDefault { get; set; }
    public bool Success { get; set; }

    public FileSystemToObjectGraphServiceData(IEnumerable<string> choices, StringBuilder stdInHandlerState, StringBuilder mesg) {
      Choices = choices;
      StdInHandlerState = stdInHandlerState;
      Mesg = mesg;
    }

    #region IDisposable Support
    private bool disposedValue = false; // To detect redundant calls

    protected virtual void Dispose(bool disposing) {
      if (!disposedValue) {
        if (disposing) {
          if (SubscriptionToConsoleReadLineAsyncAsObservableDisposeHandle != null) {

            SubscriptionToConsoleReadLineAsyncAsObservableDisposeHandle.Dispose();
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
