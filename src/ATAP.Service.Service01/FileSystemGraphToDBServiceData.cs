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

using ServiceStack;

namespace FileSystemGraphToDBService {


  public class FileSystemGraphToDBServiceData : IFileSystemGraphToDBServiceData, IDisposable {
    public ConfigurationRoot ConfigurationRoot { get; }
    public IEnumerable<string> Choices { get; }
    public StringBuilder StdInHandlerState { get; }
    public StringBuilder Mesg { get; }
    public IDisposable SubscriptionToConsoleReadLineAsyncAsObservableDisposeHandle { get; set; }
    public IConvertFileSystemGraphToDBDataAndResults ConvertFileSystemGraphToDBDataAndResults { get; set; }
    public List<Task<ConvertFileSystemGraphToDBResults>> LongRunningTasks { get; }
    public Action FinishedWithStdInAction { get; set; }

    public FileSystemGraphToDBServiceData(IEnumerable<string> choices, StringBuilder stdInHandlerState, StringBuilder mesg, IConvertFileSystemGraphToDBDataAndResults convertFileSystemGraphToDBDataAndResults, List<Task<ConvertFileSystemGraphToDBResults>> longRunningTasks) {
      Choices = choices;
      StdInHandlerState = stdInHandlerState;
      Mesg = mesg;
      ConvertFileSystemGraphToDBDataAndResults = convertFileSystemGraphToDBDataAndResults;
      LongRunningTasks = longRunningTasks;
    }

    #region IDisposable Support
    private bool disposedValue = false; // To detect redundant calls

    protected virtual void Dispose(bool disposing) {
      if (!disposedValue) {
        if (disposing) {
          if (SubscriptionToConsoleReadLineAsyncAsObservableDisposeHandle != null) {
            SubscriptionToConsoleReadLineAsyncAsObservableDisposeHandle.Dispose();
          }
          if (ConvertFileSystemGraphToDBDataAndResults != null) {
              ConvertFileSystemGraphToDBDataAndResults.Dispose();
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

  public class ConvertFileSystemGraphToDBDataAndResults : IConvertFileSystemGraphToDBDataAndResults, IDisposable {
    public IConvertFileSystemGraphToDBData ConvertFileSystemGraphToDBData { get; }
    public IConvertFileSystemGraphToDBResults ConvertFileSystemGraphToDBResults { get; set; }
    public Stopwatch Stopwatch { get; set; }


    public ConvertFileSystemGraphToDBDataAndResults(IConvertFileSystemGraphToDBData convertFileSystemGraphToDBData, IConvertFileSystemGraphToDBResults convertFileSystemGraphToDBResults) {
      ConvertFileSystemGraphToDBData = convertFileSystemGraphToDBData;
      ConvertFileSystemGraphToDBResults = convertFileSystemGraphToDBResults;
    }

    #region IDisposable Support
    private bool disposedValue = false; // To detect redundant calls

    protected virtual void Dispose(bool disposing) {
      if (!disposedValue) {
        if (disposing) {
          ConvertFileSystemGraphToDBData.Dispose();
        }

        // TODO: free unmanaged resources (unmanaged objects) and override a finalizer below.
        // TODO: set large fields to null.

        disposedValue = true;
      }
    }

    // TODO: override a finalizer only if Dispose(bool disposing) above has code to free unmanaged resources.
    // ~ConvertFileSystemGraphToDBDataAndResults()
    // {
    //   // Do not change this code. Put cleanup code in Dispose(bool disposing) above.
    //   Dispose(false);
    // }

    // This code added to correctly implement the disposable pattern.
    public void Dispose() {
      // Do not change this code. Put cleanup code in Dispose(bool disposing) above.
      Dispose(true);
      // TODO: uncomment the following line if the finalizer is overridden above.
      // GC.SuppressFinalize(this);
    }
    #endregion

  }

  public class ConvertFileSystemGraphToDBData : IConvertFileSystemGraphToDBData, IDisposable {
    public string DBConnectionString { get; }
    public string OrmLiteDialectProviderStringDefault { get; }
    public int AsyncFileReadBlockSize { get; set; }
    public bool EnableProgress { get; set; }
    public IConvertFileSystemGraphToDBProgress ConvertFileSystemGraphToDBProgress { get; set; }
    public string TemporaryDirectoryBase { get; set; }
    public string NodeFileRelativePath { get; set; }
    public string EdgeFileRelativePath { get; set; }
    public string[] FilePaths { get; set; }

    public ConvertFileSystemGraphToDBData(string dBConnectionString, string ormLiteDialectProviderStringDefault, int asyncFileReadBlockSize, bool enableProgress, IConvertFileSystemGraphToDBProgress convertFileSystemGraphToDBProgress, string temporaryDirectoryBase, string nodeFileRelativePath, string edgeFileRelativePath, string[] filePaths) {
      DBConnectionString = dBConnectionString;
      OrmLiteDialectProviderStringDefault = ormLiteDialectProviderStringDefault;
      AsyncFileReadBlockSize = asyncFileReadBlockSize;
      EnableProgress = enableProgress;
      ConvertFileSystemGraphToDBProgress = convertFileSystemGraphToDBProgress;
      TemporaryDirectoryBase = temporaryDirectoryBase;
      NodeFileRelativePath = nodeFileRelativePath;
      EdgeFileRelativePath = edgeFileRelativePath;
      FilePaths = filePaths;
    }

    #region IDisposable Support
    private bool disposedValue = false; // To detect redundant calls

    protected virtual void Dispose(bool disposing) {
      if (!disposedValue) {
        if (disposing) {
          ConvertFileSystemGraphToDBProgress.Dispose();
        }

        // TODO: free unmanaged resources (unmanaged objects) and override a finalizer below.
        // TODO: set large fields to null.

        disposedValue = true;
      }
    }

    // TODO: override a finalizer only if Dispose(bool disposing) above has code to free unmanaged resources.
    // ~ConvertFileSystemGraphToDBData()
    // {
    //   // Do not change this code. Put cleanup code in Dispose(bool disposing) above.
    //   Dispose(false);
    // }

    // This code added to correctly implement the disposable pattern.
    public void Dispose() {
      // Do not change this code. Put cleanup code in Dispose(bool disposing) above.
      Dispose(true);
      // TODO: uncomment the following line if the finalizer is overridden above.
      // GC.SuppressFinalize(this);
    }
    #endregion

  }
  class ConvertFileSystemGraphToDBProgress : IConvertFileSystemGraphToDBProgress, IDisposable {
    public bool Completed { get; set; }

    public ConvertFileSystemGraphToDBProgress(bool completed) {
      Completed = completed;
    }

    #region IDisposable Support
    private bool disposedValue = false; // To detect redundant calls


    protected virtual void Dispose(bool disposing) {
      if (!disposedValue) {
        if (disposing) {
          // TODO: dispose managed state (managed objects).
        }

        // TODO: free unmanaged resources (unmanaged objects) and override a finalizer below.
        // TODO: set large fields to null.

        disposedValue = true;
      }
    }

    // TODO: override a finalizer only if Dispose(bool disposing) above has code to free unmanaged resources.
    // ~ConvertFileSystemGraphToDBProgress()
    // {
    //   // Do not change this code. Put cleanup code in Dispose(bool disposing) above.
    //   Dispose(false);
    // }

    // This code added to correctly implement the disposable pattern.
    public void Dispose() {
      // Do not change this code. Put cleanup code in Dispose(bool disposing) above.
      Dispose(true);
      // TODO: uncomment the following line if the finalizer is overridden above.
      // GC.SuppressFinalize(this);
    }
    #endregion

  }


  public class ConvertFileSystemGraphToDBResults : IConvertFileSystemGraphToDBResults, IDisposable {
    public bool Success { get; set; }

    public ConvertFileSystemGraphToDBResults(bool success) {
      Success = success;
    }

    #region IDisposable Support
    private bool disposedValue = false; // To detect redundant calls

    protected virtual void Dispose(bool disposing) {
      if (!disposedValue) {
        if (disposing) {
          // TODO: dispose managed state (managed objects).
        }

        // TODO: free unmanaged resources (unmanaged objects) and override a finalizer below.
        // TODO: set large fields to null.

        disposedValue = true;
      }
    }

    // TODO: override a finalizer only if Dispose(bool disposing) above has code to free unmanaged resources.
    // ~ConvertFileSystemGraphToDBData()
    // {
    //   // Do not change this code. Put cleanup code in Dispose(bool disposing) above.
    //   Dispose(false);
    // }

    // This code added to correctly implement the disposable pattern.
    public void Dispose() {
      // Do not change this code. Put cleanup code in Dispose(bool disposing) above.
      Dispose(true);
      // TODO: uncomment the following line if the finalizer is overridden above.
      // GC.SuppressFinalize(this);
    }
    #endregion

  }
}

