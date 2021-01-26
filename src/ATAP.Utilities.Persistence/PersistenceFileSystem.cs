using System;
using System.Linq;
using System.IO;
using System.Threading;
using System.Collections.Generic;

namespace ATAP.Utilities.Persistence {
  public interface ISetupViaFileData : ISetupDataAbstract {
    IEnumerable<string> FilePathsEnumerable { get; set; }
    IDictionary<string, string> FilePathsDictionary { get; set; }
  }

  public class SetupViaFileData : SetupDataAbstract, ISetupViaFileData {
    public SetupViaFileData(IEnumerable<string> filePaths) : this(filePaths, null) { }

    public SetupViaFileData(IEnumerable<string> filePaths, CancellationToken? cancellationToken) : base(cancellationToken) {
      FilePathsEnumerable = filePaths ?? throw new ArgumentNullException(nameof(filePaths));
      //ToDo: Create a custom exception for this, a custom exception should support serialization and implement the four basic constructors. see https://stackoverflow.com/questions/94488/what-is-the-correct-way-to-make-a-custom-net-exception-serializable and https://csharp.2000things.com/2013/07/26/896-custom-exceptions-should-be-marked-as-serializable/
      if (!filePaths.Any()) { throw new InvalidDataException(nameof(filePaths) + " has no elements"); }
    }
    public SetupViaFileData(IDictionary<string, string> filePaths) : this(filePaths, null) { }
    public SetupViaFileData(IDictionary<string, string> filePaths, CancellationToken? cancellationToken) : base(cancellationToken) {
      FilePathsDictionary = filePaths ?? throw new ArgumentNullException(nameof(filePaths));
      //ToDo: Create a custom exception for this, a custom exception should support serialization and implement the four basic constructors. see https://stackoverflow.com/questions/94488/what-is-the-correct-way-to-make-a-custom-net-exception-serializable and https://csharp.2000things.com/2013/07/26/896-custom-exceptions-should-be-marked-as-serializable/
      if (!filePaths.Keys.Any()) { throw new InvalidDataException(nameof(filePaths) + " has no elements"); }
    }

    public IEnumerable<string> FilePathsEnumerable { get; set; }
    public IDictionary<string, string> FilePathsDictionary { get; set; }

  }
  public class SetupViaFileResults : SetupResultsAbstract, ISetupViaFileResults, IDisposable {
    public SetupViaFileResults(bool success, IEnumerable<(FileStream fileStream, StreamWriter streamWriter)> fileStreamStreamWriterPairs) : base(success) {
      if (fileStreamStreamWriterPairs == null) { throw new ArgumentNullException(nameof(fileStreamStreamWriterPairs)); }
      FileStreamStreamWriterPairs = fileStreamStreamWriterPairs.ToArray<(FileStream fileStream, StreamWriter streamWriter)>();
    }

    public SetupViaFileResults(bool success, Dictionary<string, (FileStream fileStream, StreamWriter streamWriter)> dictionaryFileStreamStreamWriterPairs) : base(success) {
      DictionaryFileStreamStreamWriterPairs = dictionaryFileStreamStreamWriterPairs ?? throw new ArgumentNullException(nameof(dictionaryFileStreamStreamWriterPairs));
    }
    public (FileStream fileStream, StreamWriter streamWriter)[] FileStreamStreamWriterPairs { get; set; }

    public Dictionary<string, (FileStream fileStream, StreamWriter streamWriter)> DictionaryFileStreamStreamWriterPairs { get; init; }

    #region IDisposable Support
    private bool disposedValue = false; // To detect redundant calls

    // ToDo: Add async versions

    protected virtual void Dispose(bool disposing) {
      if (!disposedValue) {
        if (disposing) {
          if (FileStreamStreamWriterPairs != null && FileStreamStreamWriterPairs.Any()) {
            foreach (var fsp in FileStreamStreamWriterPairs) {
              // ToDo: use async version
              //Todo: ?? exception handling on call to Dispose
              fsp.streamWriter.Dispose();
              //Todo: ?? exception handling on call to Dispose
              fsp.fileStream.Dispose();
            }
          }
          else if (DictionaryFileStreamStreamWriterPairs! != null && DictionaryFileStreamStreamWriterPairs.Keys.Any()) {
            foreach (var key in DictionaryFileStreamStreamWriterPairs.Keys) {
              DictionaryFileStreamStreamWriterPairs[key].fileStream.Dispose();
              DictionaryFileStreamStreamWriterPairs[key].streamWriter.Dispose();
            }
          }
          else {
            //ToDo: add custom exception for calling dispose on a SetupViaFileResults object having both null
            throw new InvalidDataException("ToDo: localize this somewhere Dispose was called on an instance of the class SetupViaFileResults, and all of the FileStream,Streamwriter pairs were null");
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

  public interface IInsertViaFileData : IInsertDataAbstract {
    //string[][] DataEnumerableToInsert { get; set; }
    //Dictionary<string, IEnumerable<object>> DataDictionaryToInsert { get; set; }
  }

  public class InsertViaFileData : InsertDataAbstract, IInsertViaFileData {
    public InsertViaFileData(string[][] dataEnumerableToInsert) : this(dataEnumerableToInsert, null) { }

    public InsertViaFileData(string[][] dataEnumerableToInsert, CancellationToken? cancellationToken) : base(dataEnumerableToInsert, cancellationToken) {
      EnumerableDataToInsert = dataEnumerableToInsert ?? throw new ArgumentNullException(nameof(dataEnumerableToInsert));
    }
    public InsertViaFileData(Dictionary<string, IEnumerable<object>> dataDictionaryToInsert) : this(dataDictionaryToInsert, null) { }

    public InsertViaFileData(Dictionary<string, IEnumerable<object>> dataDictionaryToInsert, CancellationToken? cancellationToken) : base(dataDictionaryToInsert, cancellationToken) {
      DataDictionaryToInsert = dataDictionaryToInsert ?? throw new ArgumentNullException(nameof(dataDictionaryToInsert));
    }
    public Dictionary<string, IEnumerable<object>> DataDictionaryToInsert { get; set; }
    public string[][] DataEnumerableToInsert { get; set; }
  }

  public interface IInsertViaFileResults : IInsertResultsAbstract {

  }

  public class InsertViaFileResults : InsertResultsAbstract, IInsertViaFileResults {
    public InsertViaFileResults(bool success) : base(success) { }
  }
}
