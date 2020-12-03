using ATAP.Utilities.ComputerInventory.Hardware;

using Microsoft.Extensions.Configuration;

using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Text;
using System.Threading.Tasks;

namespace FileSystemGraphToDBService {
  public interface IFileSystemGraphToDBServiceData : IDisposable {
    ConfigurationRoot ConfigurationRoot { get; }
    IEnumerable<string> Choices { get; }
    StringBuilder Mesg { get; }
    IDisposable SubscriptionToConsoleReadLineAsyncAsObservableDisposeHandle { get; set; }
    StringBuilder StdInHandlerState { get; }
    IConvertFileSystemGraphToDBDataAndResults ConvertFileSystemGraphToDBDataAndResults { get; }
    List<Task<ConvertFileSystemGraphToDBResults>> LongRunningTasks { get; }
  }

  public interface IConvertFileSystemGraphToDBDataAndResults : IDisposable {
    IConvertFileSystemGraphToDBData ConvertFileSystemGraphToDBData { get; }
    IConvertFileSystemGraphToDBResults ConvertFileSystemGraphToDBResults { get; set; }
    Stopwatch Stopwatch { get; }
  }
  public interface IConvertFileSystemGraphToDBData : IDisposable {
    string DBConnectionString { get; }
    string OrmLiteDialectProviderStringDefault { get;  }
    int AsyncFileReadBlockSize { get; set; }
    bool EnableProgress { get; set; }
    IConvertFileSystemGraphToDBProgress ConvertFileSystemGraphToDBProgress { get; set; }
    string TemporaryDirectoryBase { get; set; }
    string NodeFileRelativePath { get; set; }
    string EdgeFileRelativePath { get; set; }
    string[] FilePaths { get; set; }
  }

  public interface IConvertFileSystemGraphToDBProgress : IDisposable {
     bool Completed { get; set; }
  }

  public interface IConvertFileSystemGraphToDBResults {
    bool Success { get; set; }
  }



}
