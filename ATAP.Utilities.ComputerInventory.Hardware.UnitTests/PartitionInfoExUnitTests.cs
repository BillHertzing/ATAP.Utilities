using ATAP.Utilities.ComputerInventory.Hardware;
using ATAP.Utilities.Testing;
using ATAP.Utilities.TypedGuids;
using FluentAssertions;
using Itenso.TimePeriod;
using System;
using System.Collections.Generic;
using System.Linq;
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
    public async Task TestConvertFileSystemToGraphAsyncTask()
    {
#if DEBUG
      TestOutput.WriteLine("starting");
#endif
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
     
      //ConvertFileSystemToGraphPersistence? convertFileSystemToGraphPersistence = null;
      //Func<Task> act = () => asyncObject.Awaiting(async x => await x.ThrowAsync<ArgumentException>());
      //act.Should().Throw<ArgumentException>();

      Func<Task<ConvertFileSystemToGraphResult>> run = () => StaticExtensions.ConvertFileSystemToGraphAsyncTask(rootstring, asyncFileReadBlockSize, convertFileSystemToGraphProgress, null, cancellationToken);
      ConvertFileSystemToGraphResult convertFileSystemToGraphResult = await run.Invoke();
      var fnames = convertFileSystemToGraphResult.GraphAsIList.Vertices.Where(x => x.Obj.GetType() == typeof(IFSEntityFile));
      var ffullnames = convertFileSystemToGraphResult.GraphAsIList.Vertices.Where(x => x.Obj.GetType() == typeof(IFSEntityFile)).Select(z => z.Obj as FSEntityFile).Where(y => (y.Path == null)).Select(z => z.FileInfo);
      var dfullnames = convertFileSystemToGraphResult.GraphAsIList.Vertices.Where(x => x.Obj.GetType() == typeof(FSEntityDirectory)).Select(z => z.Obj as FSEntityDirectory).Where(y => (y.Path != null)).Select(z => z.DirectoryInfo);
      convertFileSystemToGraphResult.GraphAsIList.Vertices.Count.Should().Be(5);
      var x = 1;
    }
  }
}
