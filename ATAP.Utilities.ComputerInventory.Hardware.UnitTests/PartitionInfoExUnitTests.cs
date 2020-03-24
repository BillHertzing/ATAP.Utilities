using ATAP.Utilities.ComputerInventory.Hardware;
using ATAP.Utilities.Testing;
using ATAP.Utilities.TypedGuids;
using ATAP.Utilities.Persistence;
using FluentAssertions;
using Itenso.TimePeriod;
using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.Linq;
using System.Text;
using System.Threading;
using System.Threading.Tasks;
using Xunit;
using Xunit.Abstractions;
using static FluentAssertions.FluentActions;


namespace ATAP.Utilities.ComputerInventory.Hardware.UnitTests
{

  public partial class ComputerInventoryHardwareUnitTests001 : IClassFixture<ComputerInventoryHardwareFixture>
  {
    [Theory]
    [MemberData(nameof(PartitionInfoExTestDataGenerator.TestData), MemberType = typeof(PartitionInfoExTestDataGenerator))]
    public void PartitionInfoExDeserializeFromJSON(PartitionInfoExTestData inTestData)
    {
      var obj = Fixture.Serializer.Deserialize<PartitionInfoEx>(inTestData.SerializedTestData);
      obj.Should().BeOfType(typeof(PartitionInfoEx));
      Fixture.Serializer.Deserialize<PartitionInfoEx>(inTestData.SerializedTestData).Should().Be(inTestData.ObjTestData);
    }

    [Theory]
    [MemberData(nameof(PartitionInfoExTestDataGenerator.TestData), MemberType = typeof(PartitionInfoExTestDataGenerator))]
    public void PartitionInfoExSerializeToJSON(PartitionInfoExTestData inTestData)
    {
#if DEBUG
      TestOutput.WriteLine("SerializedTestData is:" + inTestData.SerializedTestData);
      TestOutput.WriteLine("Serialized ObjTestData is:" + Fixture.Serializer.Serialize(inTestData.ObjTestData));
#endif
      Fixture.Serializer.Serialize(inTestData.ObjTestData).Should().Be(inTestData.SerializedTestData);
    }

    [Fact]
    public async Task TestConvertFileSystemToGraphAsyncTaskNoPersistence()
    {
      var asyncFileReadBlockSize = 4096;
      //var partitionInfoEx = new PartitionInfoEx(Hardware.Enumerations.PartitionFileSystem.NTFS, new UnitsNet.Information(1.2m, UnitsNet.Units.InformationUnit.Terabyte), new List<char>() { 'E' }, new Philote.Philote<IPartitionInfoEx>().Now());
      //var root = partitionInfoEx.DriveLetters.First();
      var root = 'E';
      // In Windows, root is a single letter, but in *nix, root is a string. Convert the single char to a string
      // ToDo: replace with ATAP.Utilities RunTimeKind, and make it *nix friendly
      var rootstring = root.ToString() + ":/";
      // Create storage for the results and progress
      var convertFileSystemToGraphProgress = new ConvertFileSystemToGraphProgress();
      // Cancellation token for the task 
      var cancellationTokenSource = new CancellationTokenSource();
      var cancellationTokenSourceId = new Id<CancellationTokenSource>(Guid.NewGuid());
      var cancellationToken = cancellationTokenSource.Token;

      Func<Task<ConvertFileSystemToGraphResult>> run = () => StaticExtensions.ConvertFileSystemToGraphAsyncTask(rootstring, asyncFileReadBlockSize, convertFileSystemToGraphProgress, null, cancellationToken);
      ConvertFileSystemToGraphResult convertFileSystemToGraphResult = await run.Invoke();
      //var fnames = convertFileSystemToGraphResult.GraphAsIList.Vertices.Where(x => x.Obj.GetType() == typeof(IFSEntityFile));

      //var ffullnames = convertFileSystemToGraphResult.GraphAsIList.Vertices.Where(x => x.Obj.GetType() == typeof(IFSEntityFile)).Select(z => z.Obj as FSEntityFile).Where(y => (y.Path == null)).Select(z => z.FileInfo);
      //var dfullnames = convertFileSystemToGraphResult.GraphAsIList.Vertices.Where(x => x.Obj.GetType() == typeof(FSEntityDirectory)).Select(z => z.Obj as FSEntityDirectory).Where(y => (y.Path != null)).Select(z => z.DirectoryInfo);
      var containeredgeandnodename = convertFileSystemToGraphResult.GraphAsIList.Edges
      //.Where(e => ((e.From.Obj.GetType() == typeof(FSEntityDirectory) && (e.To.Obj.GetType() == typeof(FSEntityFile)))))
      .Select(edge =>
      {
        string fs;
        switch (edge.From.Obj)
        {
          case FSEntityDirectory directory:
          {
            fs = (edge.From.Obj as FSEntityDirectory).DirectoryInfo.FullName;
            break;
          }
          // Handles the more-derived type FSEntityArchiveFile as well
          case FSEntityFile file:
          {
            fs = (edge.From.Obj as FSEntityFile).FileInfo.FullName;
            break;
          }
          default:
          {
            throw new Exception(string.Format(CultureInfo.CurrentCulture, StringConstants.InvalidTypeInSwitchExceptionMessage, edge.From.Obj));
          }
        }
        string ts;
        switch (edge.To.Obj)
        {
          case FSEntityDirectory directory:
          {
            ts = (edge.To.Obj as FSEntityDirectory).DirectoryInfo.FullName;
            break;
          }
          // Handles the more-derived type FSEntityArchiveFile as well
          case FSEntityFile file:
          {
            ts = (edge.To.Obj as FSEntityFile).FileInfo.FullName;
            break;
          }
          default:
          {
            throw new Exception(string.Format(CultureInfo.CurrentCulture, StringConstants.InvalidTypeInSwitchExceptionMessage, edge.To.Obj));
          }
        }
        var tu = (fs, ts);
        return tu;
      });

      var digraph = new StringBuilder();
      digraph.Append("digraph G {"); digraph.Append(Environment.NewLine);
      foreach (var e in containeredgeandnodename.ToList<(string, string)>())
      {
        digraph.Append($"\"{e.Item1.Replace("\\", "\\\\")}\" -> \"{e.Item2.Replace("\\", "\\\\")}\""); digraph.Append(Environment.NewLine);
      }
      digraph.Append("}");
      convertFileSystemToGraphResult.GraphAsIList.Vertices.Count.Should().Be(5);
    }

    // Common constructor method for the SetupViaFileFunc used in these tests
    // Sets up N empty files in the %tempt% directory
    Func<SetupViaFileData, SetupViaFileResults> SetupViaFileFuncBuilder()
    {
      Func<SetupViaFileData, SetupViaFileResults> ret = new Func<SetupViaFileData, SetupViaFileResults>((setupData) =>
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
    public async Task TestConvertFileSystemToGraphAsyncTaskFilePersistence()
    {
      // Arrange
      var asyncFileReadBlockSize = 4096;
      //var partitionInfoEx = new PartitionInfoEx(Hardware.Enumerations.PartitionFileSystem.NTFS, new UnitsNet.Information(1.2m, UnitsNet.Units.InformationUnit.Terabyte), new List<char>() { 'E' }, new Philote.Philote<IPartitionInfoEx>().Now());
      //var root = partitionInfoEx.DriveLetters.First();
      var root = 'E';
      // In Windows, root is a single letter, but in *nix, root is a string. Convert the single char to a string
      // ToDo: replace with ATAP.Utilities RunTimeKind, and make it *nix friendly
      var rootstring = root.ToString() + ":/";
      // Create storage for the results and progress
      var convertFileSystemToGraphProgress = new ConvertFileSystemToGraphProgress();
      // Cancellation token for the task 
      var cancellationTokenSource = new CancellationTokenSource();
      var cancellationTokenSourceId = new Id<CancellationTokenSource>(Guid.NewGuid());
      var cancellationToken = cancellationTokenSource.Token;
      // PersistenceViaFiles
      // Create temporary files to hold the persistence data
      var numfiles = 2;
      var temporaryFiles = new TemporaryFile[numfiles];
      var filePaths = new string[2];
      for (int i = 0; i < 2; i++)
      {
        temporaryFiles[i] = new TemporaryFile().CreateTemporaryFileEmpty();
        filePaths[i] = temporaryFiles[i].FileInfo.FullName;
#if DEBUG
        TestOutput.WriteLine($"File {i} is named {temporaryFiles[i].FileInfo.FullName}");
#endif
      }

      var setupFunc = SetupViaFileFuncBuilder();
      SetupViaFileData setupData = new SetupViaFileData(filePaths, cancellationToken);

      PersistenceViaFile persistence = new PersistenceViaFile(setupFunc(setupData), setupFunc, InsertViaFileFuncBuilder(), TearDownViaFileFuncBuilder());

      // Act
      Func<Task<ConvertFileSystemToGraphResult>> run = () => StaticExtensions.ConvertFileSystemToGraphAsyncTask(rootstring, asyncFileReadBlockSize, convertFileSystemToGraphProgress, persistence, cancellationToken);
      ConvertFileSystemToGraphResult convertFileSystemToGraphResult = await run.Invoke().ConfigureAwait(false);
      persistence.TearDownFunc(new TearDownViaFileData(), persistence.SetupResults);

      //Assert
      convertFileSystemToGraphResult.GraphAsIList.Vertices.Count.Should().Be(5);
      convertFileSystemToGraphResult.GraphAsIList.Edges.Count.Should().Be(6);

      string[] vertices = File.ReadLines(temporaryFiles[0].FileInfo.FullName) as string[];
#if DEBUG
      TestOutput.WriteLine($"File 0 (vertices) contains {vertices}");
      //TestOutput.WriteLine(vertices);
#endif
      string[] edges = File.ReadLines(temporaryFiles[1].FileInfo.FullName) as string[];
#if DEBUG
      TestOutput.WriteLine($"File 1 (edges) contains {edges}");
#endif
      vertices.Length.Should().Be(5);
      edges.Length.Should().Be(6);

    }
  }
}
