
using ATAP.Utilities.Persistence;
using ATAP.Utilities.Testing;
using ATAP.Utilities.Testing.XunitSkipAttributeExtension;
using FluentAssertions;
using static FluentAssertions.FluentActions;
using System;
using System.IO;
using System.Linq;
using System.Collections.Generic;
using System.Text;
using System.Threading;
using System.Threading.Tasks;
using Xunit;
using Xunit.Abstractions;


namespace ATAP.Utilities.Persistence.UnitTests
{
  public partial class PersistenceUnitTests001 : IClassFixture<PersistenceFixture>
  {
    // Common constructor method for the SetupViaFileFunc used in these tests
    // Sets up N empty files in the %tempt% directory
    Func<SetupViaFileData, ISetupViaFileResults> SetupViaFileFuncBuilder()
    {
      Func<SetupViaFileData, ISetupViaFileResults> ret = new Func<SetupViaFileData, ISetupViaFileResults>((setupData) =>
      {
        var filePathsAsArray = setupData.FilePaths.ToArray();
        int numberOfFiles = filePathsAsArray.Length;
#if DEBUG
        TestOutput.WriteLine($"Got {numberOfFiles} FilePaths");
#endif 

        FileStream[] fileStreams = new FileStream[numberOfFiles];
        StreamWriter[] streamWriters = new StreamWriter[numberOfFiles];
        for (var i = 0; i < numberOfFiles; i++)
        {
          fileStreams[i] = new FileStream(filePathsAsArray[i], FileMode.CreateNew, FileAccess.Write);
          //ToDo: exception handling
          streamWriters[i] = new StreamWriter(fileStreams[i], Encoding.UTF8);
          //ToDo: exception handling
        }
        return new SetupViaFileResults(true, fileStreams, streamWriters);
      });
      return ret;
    }

    // Common constructor method for the InsertViaFileFunc used in these tests
    // Uses the structures setup by the SetupViaFileFuncBuilder
    Func<IInsertViaFileData, ISetupViaFileResults, InsertViaFileResults> InsertViaFileFuncBuilder()
    {
      Func<IInsertViaFileData, ISetupViaFileResults, InsertViaFileResults> ret = new Func<IInsertViaFileData, ISetupViaFileResults, InsertViaFileResults>((insertData, setupResults) =>
      {
        int numberOfFiles = insertData.DataToInsert[0].Length;
#if DEBUG
        TestOutput.WriteLine($"Got {numberOfFiles} arrays of data to write");
#endif
        int numberOfStreamWriters = setupResults.StreamWriters.Length;
#if DEBUG
        TestOutput.WriteLine($"Got {numberOfStreamWriters} streamwriters to write to");
#endif
        for (var i = 0; i < numberOfFiles; i++)
        {
          foreach (string str in insertData.DataToInsert[i])
          {
            //await setupResults.StreamWriters[i].WriteLineAsync(str);
            setupResults.StreamWriters[i].WriteLine(str);
          }
        }
        return new InsertViaFileResults(true);

      });
      return ret;
    }

    // Common constructor method for the TearDownViaFileFunc used in these tests
    // Uses the structures setup by the SetupViaFileFuncBuilder
    Func<TearDownViaFileData, ISetupViaFileResults, TearDownViaFileResults> TearDownViaFileFuncBuilder()
    {
      Func<TearDownViaFileData, ISetupViaFileResults, TearDownViaFileResults> ret = new Func<TearDownViaFileData, ISetupViaFileResults, TearDownViaFileResults>((tearDownData, setupResults) =>
    {
      int numberOfFiles = setupResults.FileStreams.Length;
#if DEBUG
      TestOutput.WriteLine($"Got {numberOfFiles} filestreams and streamwriters to dispose");
#endif

      for (var i = 0; i < numberOfFiles; i++)
      {
        setupResults.StreamWriters[i].Dispose();
        //Todo: ?? exception handling on call to Dispose
        setupResults.FileStreams[i].Dispose();
        //Todo: ?? exception handling on call to Dispose
      }
      return new TearDownViaFileResults(true);

    });
      return ret;
    }

    [Fact]
    void VerifySetupViaFileDataThrowsOnEmptyIEnumerable()
    {
      string[] filePaths = new string[0];
      Invoking(() => new SetupViaFileData(filePaths))
    .Should().Throw<InvalidDataException>()
    .WithMessage("filePaths has no elements");
    }

    [Theory]
    [InlineData(1)]
    [InlineData(2)]
    void VerifySetupCreatesCorrectNumberOfResultElements(int inTestData)
    {
      var setupViaFileFunc = SetupViaFileFuncBuilder();

      var temporaryFiles = new TemporaryFile[inTestData];
      var filePaths = new string[inTestData];
      for (int i = 0; i < inTestData; i++)
      {
        temporaryFiles[i] = new TemporaryFile().CreateTemporaryFileEmpty();
        filePaths[i] = temporaryFiles[i].FileInfo.FullName;
      }
      var setupViaFileData = new SetupViaFileData(filePaths);
      var setupViaFileResults = setupViaFileFunc(setupViaFileData);
      setupViaFileResults.Success.Should().Be(true);
      setupViaFileResults.FileStreams.Length.Should().Be(inTestData);
      setupViaFileResults.StreamWriters.Length.Should().Be(inTestData);
    }

    [Theory]
    [InlineData(1)]
    [InlineData(2)]
    void VerifyTearDown(int inTestData)
    {
      var setupViaFileFunc = SetupViaFileFuncBuilder();

      var temporaryFiles = new TemporaryFile[inTestData];
      var filePaths = new string[inTestData];
      for (int i = 0; i < inTestData; i++)
      {
        temporaryFiles[i] = new TemporaryFile().CreateTemporaryFileEmpty();
        filePaths[i] = temporaryFiles[i].FileInfo.FullName;
      }
      var setupViaFileData = new SetupViaFileData(filePaths);
      var setupViaFileResults = setupViaFileFunc(setupViaFileData);
      setupViaFileResults.Success.Should().Be(true);
      setupViaFileResults.FileStreams.Length.Should().Be(inTestData);
      setupViaFileResults.StreamWriters.Length.Should().Be(inTestData);
      var tearDownViaFileData = new TearDownViaFileData();
      var tearDownViaFileFunc = TearDownViaFileFuncBuilder();
      var tearDownViaFileResults = tearDownViaFileFunc(tearDownViaFileData, setupViaFileResults);
      setupViaFileResults.Success.Should().Be(true);
      // ToDo: add tests to confirm the structures are marked disposed
    }

    [Theory]
    //[InlineData( (1, "placeholder" ))]
    [InlineData(2)]
    void VerifyInsert(int inTestData)
    {
      var setupViaFileFunc = SetupViaFileFuncBuilder();

      var temporaryFiles = new TemporaryFile[inTestData];
      var filePaths = new string[inTestData];
      for (int i = 0; i < inTestData; i++)
      {
        temporaryFiles[i] = new TemporaryFile().CreateTemporaryFileEmpty();
        filePaths[i] = temporaryFiles[i].FileInfo.FullName;
      }
      var setupViaFileData = new SetupViaFileData(filePaths);
      var setupViaFileResults = setupViaFileFunc(setupViaFileData);
      setupViaFileResults.Success.Should().Be(true);

      var insertViaFileFunc = InsertViaFileFuncBuilder();

      string[] dataForFile1 = new string[] { "one", "two" };
      string[] dataForFile2 = new string[] { "fox", "bear", "cat" };
      string[][] dataForInsertViaFileData = new string[][] { dataForFile1, dataForFile2 };

      var insertViaFileData = new InsertViaFileData(dataForInsertViaFileData);
      var insertViaFilResults = insertViaFileFunc(insertViaFileData, setupViaFileResults);
      insertViaFilResults.Success.Should().Be(true);
      var tearDownViaFileData = new TearDownViaFileData();
      var tearDownViaFileFunc = TearDownViaFileFuncBuilder();
      var tearDownViaFileResults = tearDownViaFileFunc(tearDownViaFileData, setupViaFileResults);
      long CountLinesLINQ(FileInfo file) => File.ReadLines(file.FullName).Count(); // replace with a File Utility https://www.nimaara.com/, or pull in his library
                                                                                   //for (int i = 0; i < inTestData; i++)
                                                                                   //{
                                                                                   //  CountLinesLINQ(temporaryFiles[i].FileInfo).Should().Be(2);
                                                                                   //}
                                                                                   //  CountLinesLINQ(temporaryFiles[i].FileInfo).Should().Be(2);
      CountLinesLINQ(temporaryFiles[0].FileInfo).Should().Be(2);
      CountLinesLINQ(temporaryFiles[1].FileInfo).Should().Be(3);
    }

    [Theory]
    //[InlineData( (1, "placeholder" ))]
    [InlineData(2)]
    void VerifyPersistenceObject(int inTestData)
    {
      PersistenceViaFile persistenceViaFile = new PersistenceViaFile(null, SetupViaFileFuncBuilder(), InsertViaFileFuncBuilder(), TearDownViaFileFuncBuilder());

      var temporaryFiles = new TemporaryFile[inTestData];
      var filePaths = new string[inTestData];
      for (int i = 0; i < inTestData; i++)
      {
        temporaryFiles[i] = new TemporaryFile().CreateTemporaryFileEmpty();
        filePaths[i] = temporaryFiles[i].FileInfo.FullName;
      }
      var setupViaFileData = new SetupViaFileData(filePaths);

      persistenceViaFile.SetupResults = persistenceViaFile.SetupFunc(setupViaFileData);
      persistenceViaFile.SetupResults.Success.Should().Be(true);
      persistenceViaFile.SetupResults.FileStreams.Length.Should().Be(inTestData);
      persistenceViaFile.SetupResults.StreamWriters.Length.Should().Be(inTestData);

      string[] dataForFile1 = new string[] { "one", "two" };
      string[] dataForFile2 = new string[] { "fox", "bear", "cat" };
      string[][] dataForInsertViaFileData = new string[][] { dataForFile1, dataForFile2 };
      var insertViaFileData = new InsertViaFileData(dataForInsertViaFileData);

      var insertViaFileResults = persistenceViaFile.InsertFunc(insertViaFileData, persistenceViaFile.SetupResults);
      insertViaFileResults.Success.Should().Be(true);

      var tearDownViaFileData = new TearDownViaFileData();
      var tearDownViaFileResults = persistenceViaFile.TearDownFunc(tearDownViaFileData, persistenceViaFile.SetupResults);

      long CountLinesLINQ(FileInfo file) => File.ReadLines(file.FullName).Count();
      CountLinesLINQ(temporaryFiles[0].FileInfo).Should().Be(2);
      CountLinesLINQ(temporaryFiles[1].FileInfo).Should().Be(3);
    }

  }
}

/*
public partial class PersistenceUnitTests001 : IClassFixture<PersistenceFixture>
{

[SkipBecauseNotWorkingTheory]
[MemberData(nameof(PersistenceViaFileTestDataGenerator.TestData), MemberType = typeof(PersistenceViaFileTestDataGenerator))]
public void PersistenceViaFileDeserializeFromJSON(PersistenceViaFileTestData inTestData)
{
//var obj = Fixture.Serializer.Deserialize<PersistenceViaFile>(inTestData.SerializedTestData);
//obj.Should().BeOfType(typeof(PersistenceViaFile));
//Fixture.Serializer.Deserialize<PersistenceViaFile>(inTestData.SerializedTestData).Should().BeEquivalentTo(inTestData.ObjTestData);
}
// Simple Task result type for a simple test Task
class TestTaskResult
{
public TestTaskResult(bool success)
{
  Success = success;
}
public bool Success { get; set; }
}

[Fact]
public void TestPersistenceViaFile()
{

// Cancellation token for the task 
var cancellationTokenSource = new CancellationTokenSource();
var cancellationToken = cancellationTokenSource.Token;

// Create a temporary file to hold the persistence data
var temporaryFileVertices = new TemporaryFile();
var temporaryFileEdges = new TemporaryFile();


// Create a Function that opens all files and returns an IEnumerable of FileStreams and streamwriters.
// ToDo: Create a builder class to implement the persistence structure, and use it (or mock it) here
PersistenceViaFileSetupInitializationData persistenceSetupInitializationData = new PersistenceViaFileSetupInitializationData(new string[2] { temporaryFileVertices.FileInfo.FullName, temporaryFileEdges.FileInfo.FullName }, cancellationToken);
PersistenceViaFileSetupResults? persistenceSetupResults = null;
Func<IPersistenceViaFileSetupInitializationData, IPersistenceViaFileSetupResults> persistenceSetupFunc = new Func<IPersistenceViaFileSetupInitializationData, IPersistenceViaFileSetupResults>((persistenceViaFileSetupInitializationData) =>
{
  //ToDo: argument exception handling
  string[] filePaths = persistenceViaFileSetupInitializationData.FilePaths.ToArray<string>();
  int numberOfFiles = filePaths.Length;
  FileStream[] fileStreams = new FileStream[numberOfFiles];
  StreamWriter[] streamWriters = new StreamWriter[numberOfFiles];
  for (var i = 0; i < numberOfFiles; i++)
  {
    fileStreams[i] = new FileStream(filePaths[i], FileMode.OpenOrCreate);
    //ToDo: exception handling
    streamWriters[i] = new StreamWriter(fileStreams[i], Encoding.UTF8);
    //ToDo: exception handling
  }
  return new PersistenceViaFileSetupResults(fileStreams, streamWriters, true);
});

PersistenceViaFileInsertData? persistenceInsertData = null;
PersistenceViaFileInsertResults? persistenceInsertResults = null;
Func<IPersistenceViaFileInsertData, IPersistenceViaFileSetupResults, IPersistenceViaFileInsertResults> persistenceInsertFunc = new Func<IPersistenceViaFileInsertData, IPersistenceViaFileSetupResults, IPersistenceViaFileInsertResults>((persistenceViaFileInsertData, persistenceViaFileSetupResults) => {
  //ToDo: argument exception handling
  //Convert DataToInsert to arrays of strings and write to the corresponding Streamwriter
  StringWriter[] stringWriters = persistenceViaFileSetupResults.StreamWriters.ToArray<StringWriter>();
  string[] dataToInsert = persistenceViaFileInsertData.DataToInsert.ToArray<string>();
  return new PersistenceViaFileInsertResults( true);
});
PersistenceViaFileTearDownData persistenceTearDownData = null;
PersistenceViaFileTearDownResults persistenceTearDownResults = null;
Func<IPersistenceViaFileTearDownData, IPersistenceViaFileSetupResults, IPersistenceViaFileTearDownResults> persistenceTearDownFunc = new Func<IPersistenceViaFileTearDownData, IPersistenceViaFileSetupResults, IPersistenceViaFileTearDownResults>((persistenceViaFileTearDownData, persistenceViaFileSetupResults) =>
{
  return new PersistenceViaFileTearDownResults( true);
});
  // persistenceSetupResults = persistenceSetupFunc(persistenceSetupInitializationData).Invoke();
  PersistenceViaFile persistence = new PersistenceViaFile(persistenceSetupInitializationData, persistenceSetupResults, persistenceSetupFunc, persistenceInsertData, persistenceInsertResults, persistenceInsertFunc, persistenceTearDownData, persistenceTearDownResults, persistenceTearDownFunc);

// Create and run simple test Task that takes a Persistence object and returns a TestTaskResult object
var t = Task<TestTaskResult>.Factory.StartNew((persistence) =>
{
  var result = new TestTaskResult(false);
  for (var i = 0; i < 10; i++)
  {

  }
  result.Success = true;
  return result;
}, persistence);



string[] persistedstrings0 = File.ReadLines(temporaryFileVertices.FileInfo.FullName) as string[];
string[] persistedstrings1 = File.ReadLines(temporaryFileEdges.FileInfo.FullName) as string[];
persistedstrings0.Length.Should().Be(5);
persistedstrings1.Length.Should().Be(5);
persistedstrings0.Should().BeEquivalentTo(100);
temporaryFileEdges.Should().BeEquivalentTo(100);
temporaryFileVertices.Dispose();
temporaryFileEdges.Dispose();

}
}
  */

