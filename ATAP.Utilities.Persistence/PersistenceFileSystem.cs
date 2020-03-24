using System;
using System.Linq;
using System.IO;
using System.Threading;
using System.Collections.Generic;

namespace ATAP.Utilities.Persistence
{
  public interface ISetupViaFileData : ISetupDataAbstract
  {
    IEnumerable<string> FilePaths { get; set; }
  }

  public class SetupViaFileData : SetupDataAbstract, ISetupViaFileData
  {
    public SetupViaFileData(IEnumerable<string> filePaths) : this(filePaths, null) { }

    public SetupViaFileData(IEnumerable<string> filePaths, CancellationToken? cancellationToken) : base(cancellationToken)
    {
      FilePaths = filePaths ?? throw new ArgumentNullException(nameof(filePaths));
      //ToDo: Create a custom exception for this, a custom exception should support serialization and implement the four basic constructors. see https://stackoverflow.com/questions/94488/what-is-the-correct-way-to-make-a-custom-net-exception-serializable and https://csharp.2000things.com/2013/07/26/896-custom-exceptions-should-be-marked-as-serializable/
      if (!filePaths.Any()) { throw new InvalidDataException(nameof(filePaths) + " has no elements"); }
    }

    public IEnumerable<string> FilePaths { get; set; }

  }

  public interface ISetupViaFileResults : ISetupResultsAbstract
  {
    FileStream[] FileStreams { get; set; }
    StreamWriter[] StreamWriters { get; set; }
  }

  public class SetupViaFileResults : SetupResultsAbstract, ISetupViaFileResults, IDisposable
  {
    public SetupViaFileResults(bool success, FileStream[] fileStreams, StreamWriter[] streamWriters) : base(success)
    {
      FileStreams = fileStreams ?? throw new ArgumentNullException(nameof(fileStreams));
      StreamWriters = streamWriters ?? throw new ArgumentNullException(nameof(streamWriters));
    }

    public FileStream[] FileStreams { get; set; }
    public StreamWriter[] StreamWriters { get; set; }

    #region IDisposable Support
    private bool disposedValue = false; // To detect redundant calls

    protected virtual void Dispose(bool disposing)
    {
      if (!disposedValue)
      {
        if (disposing)
        {
          int numberOfFiles = FileStreams.Length;
          for (var i = 0; i < numberOfFiles; i++)
          {
            StreamWriters[i].Dispose();
            //Todo: ?? exception handling on call to Dispose
            FileStreams[i].Dispose();
            //Todo: ?? exception handling on call to Dispose
          }
        }

        disposedValue = true;
      }
    }

    // This code added to correctly implement the disposable pattern.
    public void Dispose()
    {
      // Do not change this code. Put cleanup code in Dispose(bool disposing) above.
      Dispose(true);
    }
    #endregion
  }

  public interface IInsertViaFileData : IInsertDataAbstract
  {
    new string[][] DataToInsert { get; set; }
  }

  public class InsertViaFileData : InsertDataAbstract, IInsertViaFileData
  {
    public InsertViaFileData(string[][] dataToInsert) : this(dataToInsert, null) { }

    public InsertViaFileData(string[][] dataToInsert, CancellationToken? cancellationToken) : base(dataToInsert, cancellationToken)
    {
      DataToInsert = dataToInsert ?? throw new ArgumentNullException(nameof(dataToInsert));
    }

    new public string[][] DataToInsert { get; set; }
  }

  public interface IInsertViaFileResults : IInsertResultsAbstract
  {

  }
  public class InsertViaFileResults : InsertResultsAbstract, IInsertViaFileResults
  {
    public InsertViaFileResults(bool success) : base(success) { }
  }
}
