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
using ATAP.Utilities.GraphDataStructures;


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
      var containeredgeandnodename = convertFileSystemToGraphResult.GraphAsIList.Edges
      .Select(edge =>
      {
        string fs = edge.From.Obj.GetFullName();
        string ts = edge.To.Obj.GetFullName();
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
#if DEBUG
      TestOutput.WriteLine($"{digraph}");
#endif
      convertFileSystemToGraphResult.GraphAsIList.Vertices.Count.Should().Be(15);
    }

    // // Common constructor method for the SetupViaFileFunc used in these tests
    // // Sets up N empty files in the %tempt% directory
    // Func<SetupViaFileData, SetupViaFileResults> SetupViaFileFuncBuilder()
    // {
      // Func<SetupViaFileData, SetupViaFileResults> ret = new Func<SetupViaFileData, SetupViaFileResults>((setupData) =>
      // {
        // var filePathsAsArray = setupData.FilePaths.ToArray();
        // int numberOfFiles = filePathsAsArray.Length;
// #if DEBUG
        // TestOutput.WriteLine($"Got {numberOfFiles} FilePaths");
// #endif 

        // FileStream[] fileStreams = new FileStream[numberOfFiles];
        // StreamWriter[] streamWriters = new StreamWriter[numberOfFiles];
        // for (var i = 0; i < numberOfFiles; i++)
        // {
          // fileStreams[i] = new FileStream(filePathsAsArray[i], FileMode.CreateNew, FileAccess.Write);
          // //ToDo: exception handling
          // streamWriters[i] = new StreamWriter(fileStreams[i], Encoding.UTF8);
          // //ToDo: exception handling
        // }
        // return new SetupViaFileResults(true, fileStreams, streamWriters);
      // });
      // return ret;
    // }

    //    // Common constructor method for the InsertViaFileFunc used in these tests
    //    // closes over the ISetupViaFileResults that was pseed into the contructor
    //    Func<IInsertViaFileData, ISetupViaFileResults, Func<IInsertViaFileData, ISetupViaFileResults, IInsertViaFileResults>> InsertViaFileFuncBuilder()
    //    {
    //      Func<IInsertViaFileData, ISetupViaFileResults, Func < IInsertViaFileData, ISetupViaFileResults, IInsertViaFileResults >> insertFunc = new Func<IInsertViaFileData, ISetupViaFileResults, Func<IInsertViaFileData, ISetupViaFileResults, IInsertViaFileResults>> ((insertData, setupResults) =>
    //      {
    //        // ToDo: should the two input objects have matching cardinality?
    //        int numberOfFiles = insertData.DataToInsert[0].Length;
    //#if DEBUG
    //        TestOutput.WriteLine($"Got {numberOfFiles} arrays of data to write");
    //#endif
    //        int numberOfStreamWriters = setupResults.StreamWriters.Length;
    //#if DEBUG
    //        TestOutput.WriteLine($"Got {numberOfStreamWriters} streamwriters to write to");
    //#endif
    //        for (var i = 0; i < numberOfFiles; i++)
    //        {
    //          foreach (string str in insertData.DataToInsert[i])
    //          {
    //            //await setupResults.StreamWriters[i].WriteLineAsync(str); // ToDo: Make an anysc version
    //            setupResults.StreamWriters[i].WriteLine(str);
    //          }
    //        }
    //        InsertViaFileResults results = new InsertViaFileResults(true);
    //        IInsertViaFileResults returnInterface = results;
    //        return returnInterface;

    //      });
    //      return insertFunc;
    //    }


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

      // Call the SetupViaFileFuncBuilder here, execute the Func that comes back, with filePaths as the argument
      var setupResults = ATAP.Utilities.Persistence.StaticExtensions.SetupViaFileFuncBuilder()(new SetupViaFileData(filePaths));

      //var insertFunc = InsertViaFileFuncBuilder(setupResults);
      // Create an insertFunc that references the local variable setupResults, closing over it
      var insertFunc = new Func<IEnumerable<IEnumerable<object>>, IInsertViaFileResults>((insertData) =>
      {
        int numberOfFiles = insertData.ToArray().Length;
#if DEBUG
        TestOutput.WriteLine($"Got {numberOfFiles} arrays of data to write");
#endif
        int numberOfStreamWriters = setupResults.StreamWriters.Length;
#if DEBUG
        TestOutput.WriteLine($"Got {numberOfStreamWriters} streamwriters to write to");
#endif
        for (var i = 0; i < numberOfFiles; i++)
        {
          foreach (string str in insertData.ToArray()[i])
          {
            //ToDo: add async versions await setupResults.StreamWriters[i].WriteLineAsync(str);
            //ToDo: exception handling
            setupResults.StreamWriters[i].WriteLine(str);
#if DEBUG
            TestOutput.WriteLine($"writing {str} to file {i}");
#endif
          }
        }
        return new InsertViaFileResults(true);
      });

      Persistence<IInsertResultsAbstract> persistence = new Persistence<IInsertResultsAbstract>(insertFunc);

      // Act
      Func<Task<ConvertFileSystemToGraphResult>> run = () => StaticExtensions.ConvertFileSystemToGraphAsyncTask(rootstring, asyncFileReadBlockSize, convertFileSystemToGraphProgress, persistence, cancellationToken);
      ConvertFileSystemToGraphResult convertFileSystemToGraphResult = await run.Invoke().ConfigureAwait(false);
      setupResults.Dispose();

      //Assert
      convertFileSystemToGraphResult.GraphAsIList.Vertices.Count.Should().Be(15);
      convertFileSystemToGraphResult.GraphAsIList.Edges.Count.Should().Be(14);
      // Convert the IList objects to List objects
      List<IVertex<IFSEntityAbstract>> verticesAsAbstract = convertFileSystemToGraphResult.GraphAsIList.Vertices.ToList();
      List<IEdge<IFSEntityAbstract>> edgesAsAbstract = convertFileSystemToGraphResult.GraphAsIList.Edges.ToList();
      verticesAsAbstract.Count.Should().Be(15);
      edgesAsAbstract.Count.Should().Be(14);
      List<string> verticesAsString = verticesAsAbstract.Select(x => x.Obj.GetFullName()).ToList();
      List<string> edgesAsString = edgesAsAbstract.Select((x) => x.From.Obj.GetFullName() + " -> " + x.To.Obj.GetFullName()).ToList(); ;
      List<string> verticesfromFile = File.ReadLines(temporaryFiles[0].FileInfo.FullName).ToList();
      List<string> edgesfromFile = File.ReadLines(temporaryFiles[1].FileInfo.FullName).ToList();
#if DEBUG
      TestOutput.WriteLine($"File 0 (vertices) contains {verticesfromFile.Count()} vertices");
      foreach (var str in verticesfromFile)
      {
        TestOutput.WriteLine(str);
      }
      TestOutput.WriteLine($"File 1 (edges) contains {edgesfromFile.Count()} edges");
      foreach (var str in edgesfromFile)
      {
        TestOutput.WriteLine(str);
      }
#endif
      //verticesfromFile.Count.Should().Be(15);
      //edgesfromFile.Count.Should().Be(14);
      verticesAsString.Should().BeEquivalentTo(verticesfromFile);
      edgesAsString.Should().BeEquivalentTo(edgesfromFile);
    }
  }
}
