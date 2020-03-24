using System;
using System.Linq;
using System.IO;
using System.Threading;
using System.Collections.Generic;

namespace ATAP.Utilities.Persistence
{
  public interface ISetupViaFileData:ISetupDataAbstract
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

  public class SetupViaFileResults : SetupResultsAbstract, ISetupViaFileResults
  {
    public SetupViaFileResults(bool success, FileStream[] fileStreams, StreamWriter[] streamWriters) : base(success)
    {
      FileStreams = fileStreams ?? throw new ArgumentNullException(nameof(fileStreams));
      StreamWriters = streamWriters ?? throw new ArgumentNullException(nameof(streamWriters));
    }

    public FileStream[] FileStreams { get; set; }
    public StreamWriter[] StreamWriters { get; set; }
  }

  public interface IInsertViaFileData:IInsertDataAbstract
  {
    new string[][] DataToInsert { get; set; }
  }

  public class InsertViaFileData : InsertDataAbstract, IInsertViaFileData
  {
    public InsertViaFileData(string[][] dataToInsert) : this(dataToInsert, null) { }

    public InsertViaFileData(string[][] dataToInsert, CancellationToken? cancellationToken) : base(dataToInsert, cancellationToken)
    {
      //ToDo: Validate the cardinality of the dataToInsert matches the cardinality of the setupResults, throw if not
      DataToInsert = dataToInsert ?? throw new ArgumentNullException(nameof(dataToInsert));
    }

    new public string[][] DataToInsert { get; set; }
  }

  public interface IInsertViaFileResults : IInsertResultsAbstract
  {

  }
  public class InsertViaFileResults : InsertResultsAbstract
  {
    public InsertViaFileResults(bool success) : base(success) { }

  }


  public interface ITearDownViaFileData { }
  public class TearDownViaFileData : TearDownDataAbstract, ITearDownDataAbstract, ITearDownViaFileData
  {
    public TearDownViaFileData() : this(null)
    {
    }

    public TearDownViaFileData( CancellationToken? cancellationToken) : base(cancellationToken)
    {
    }
  }

  public interface ITearDownViaFileResults { }
  public class TearDownViaFileResults : TearDownResultsAbstract, ITearDownResultsAbstract, ITearDownViaFileResults
  {
    public TearDownViaFileResults() : this(false)
    {
    }

    public TearDownViaFileResults(bool success) : base(success)
    {
    }
  }

  public interface IPersistenceViaFile :IPersistenceAbstract
  {
    new ISetupViaFileResults SetupResults { get; set; }
    new Func<SetupViaFileData, ISetupViaFileResults> SetupFunc { get; set; }
    new Func<InsertViaFileData, ISetupViaFileResults, InsertViaFileResults> InsertFunc { get; set; }
    new Func<TearDownViaFileData, ISetupViaFileResults, TearDownViaFileResults> TearDownFunc { get; set; }
  }

  public class PersistenceViaFile : PersistenceAbstract , IPersistenceViaFile

  {
    public PersistenceViaFile(ISetupViaFileResults? setupResults, Func<SetupViaFileData, ISetupViaFileResults> setupFunc,  Func<InsertViaFileData, ISetupViaFileResults, InsertViaFileResults> insertFunc, Func<TearDownViaFileData, ISetupViaFileResults, TearDownViaFileResults> tearDownFunc) : base()
    {
      SetupResults = setupResults;
      SetupFunc = setupFunc ?? throw new ArgumentNullException(nameof(setupFunc));
      InsertFunc = insertFunc ?? throw new ArgumentNullException(nameof(insertFunc));
      TearDownFunc = tearDownFunc ?? throw new ArgumentNullException(nameof(tearDownFunc));
    }

    new public ISetupViaFileResults? SetupResults { get; set; }
    new public Func<SetupViaFileData, ISetupViaFileResults> SetupFunc { get; set; }
    new public Func<InsertViaFileData, ISetupViaFileResults, InsertViaFileResults> InsertFunc { get; set; }
    new public Func<TearDownViaFileData, ISetupViaFileResults, TearDownViaFileResults> TearDownFunc { get; set; }
  }
}
