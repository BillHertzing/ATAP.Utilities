using System;
using System.Collections.Generic;
using System.Linq;
using System.Timers;
using FluentAssertions;
using Xunit;
using Xunit.Abstractions;
using ServiceStack.Text;
using ATAP.Utilities.ComputerInventory.Enumerations;
using ATAP.Utilities.ComputerInventory.Extensions;
using ATAP.Utilities.ComputerInventory.Configuration;
using Itenso.TimePeriod;
using ATAP.Utilities.ComputerInventory.Configuration.ProcessInfo;
using ATAP.Utilities.ComputerInventory.Configuration.Hardware;
using ATAP.Utilities.ComputerInventory.Configuration.Software;
using ATAP.Utilities.ComputerInventory.Interfaces.Software;
using System.Text;
using ATAP.Utilities.ComputerInventory.Interfaces.Hardware;
using ATAP.Utilities.ComputerInventory.Models.Hardware;
using ATAP.Utilities.Testing;

namespace ATAP.Utilities.ComputerInventory.UnitTests
{
  public class Hardwarefixture : Fixture
  {
    public Hardwarefixture() : base()
    {
    }

  }

  public class ModelsHardwareUnitTests001 : IClassFixture<Hardwarefixture>
  {
    protected Hardwarefixture Fixture { get; }
    protected ITestOutputHelper TestOutput { get; }

    public ModelsHardwareUnitTests001(ITestOutputHelper testOutput, Hardwarefixture fixture)
    {
      Fixture = fixture;
      TestOutput = testOutput;
    }

    [Theory]
    [MemberData(nameof(CPUTestDataGenerator.CPUTestData), MemberType = typeof(CPUTestDataGenerator))]
    public void CPUDeserializeFromJSON(CPUTestData inCPUTestData)
    {
      var cPU = Fixture.Serializer.Deserialize<CPU>(inCPUTestData.SerializedCPU);
      cPU.Should().BeOfType(typeof(CPU));
      Fixture.Serializer.Deserialize<CPU>(inCPUTestData.SerializedCPU).Should().Be(inCPUTestData.CPU);
    }

    [Theory]
    [MemberData(nameof(CPUTestDataGenerator.CPUTestData), MemberType = typeof(CPUTestDataGenerator))]
    public void CPUSerializeToJSON(CPUTestData inCPUTestData)
    {
      string str = Fixture.Serializer.Serialize(inCPUTestData.CPU);
      // TestOutput.WriteLine(str);
      str.Should().Be(inCPUTestData.SerializedCPU);
    }

    [Theory]
    [MemberData(nameof(CPUArrayTestDataGenerator.CPUArrayTestData), MemberType = typeof(CPUArrayTestDataGenerator))]
    public void CPUArrayDeserializeFromJSON(CPUArrayTestData inCPUArrayTestData)
    {
      var cPUArray = Fixture.Serializer.Deserialize<CPU[]>(inCPUArrayTestData.SerializedCPUArray);
      cPUArray.Should().BeOfType(typeof(CPU[]));
      cPUArray.Should().BeEquivalentTo(inCPUArrayTestData.CPUArray);
    }

    [Theory]
    [MemberData(nameof(CPUArrayTestDataGenerator.CPUArrayTestData), MemberType = typeof(CPUArrayTestDataGenerator))]
    public void CPUArraySerializeToJSON(CPUArrayTestData inCPUArrayTestData)
    {
      string str = Fixture.Serializer.Serialize(inCPUArrayTestData.CPUArray);
      str.Should().Be(inCPUArrayTestData.SerializedCPUArray);
    }

    [Theory]
    [MemberData(nameof(CPUSocketTestDataGenerator.CPUSocketTestData), MemberType = typeof(CPUSocketTestDataGenerator))]
    public void CPUSocketDeserializeFromJSON(CPUSocketTestData inCPUSocketTestData)
    {
      var cPUSocket = Fixture.Serializer.Deserialize<CPUSocket>(inCPUSocketTestData.SerializedCPUSocket);
      cPUSocket.Should().BeOfType(typeof(CPUSocket));
      Fixture.Serializer.Deserialize<CPUSocket>(inCPUSocketTestData.SerializedCPUSocket).Should().Be(inCPUSocketTestData.CPUSocket);
    }

    [Theory]
    [MemberData(nameof(CPUSocketTestDataGenerator.CPUSocketTestData), MemberType = typeof(CPUSocketTestDataGenerator))]
    public void CPUSocketSerializeToJSON(CPUSocketTestData inCPUSocketTestData)
    {
      Fixture.Serializer.Serialize(inCPUSocketTestData.CPUSocket).Should().Be(inCPUSocketTestData.SerializedCPUSocket);
    }

    [Theory]
    [MemberData(nameof(PowerConsumptionTestDataGenerator.PowerConsumptionTestData), MemberType = typeof(PowerConsumptionTestDataGenerator))]
    public void PowerConsumptionDeserializeFromJSON(PowerConsumptionTestData inPowerConsumptionTestData)
    {
      var powerConsumption = Fixture.Serializer.Deserialize<PowerConsumption>(inPowerConsumptionTestData.SerializedPowerConsumption);
      powerConsumption.Should().BeOfType(typeof(PowerConsumption));
      powerConsumption.Should().Be(inPowerConsumptionTestData.PowerConsumption);
    }

    [Theory]
    [MemberData(nameof(PowerConsumptionTestDataGenerator.PowerConsumptionTestData), MemberType = typeof(PowerConsumptionTestDataGenerator))]
    public void PowerConsumptionSerializeToJSON(PowerConsumptionTestData inPowerConsumptionTestData)
    {
      string str = Fixture.Serializer.Serialize(inPowerConsumptionTestData.PowerConsumption);
      str.Should().Be(inPowerConsumptionTestData.SerializedPowerConsumption);
    }

    [Theory]
    [MemberData(nameof(TempAndFanTestDataGenerator.TempAndFanTestData), MemberType = typeof(TempAndFanTestDataGenerator))]
    public void TempAndFanDeserializeFromJSON(TempAndFanTestData inTempAndFanTestData)
    {
      var tempAndFan = Fixture.Serializer.Deserialize<TempAndFan>(inTempAndFanTestData.SerializedTempAndFan);
      tempAndFan.Should().BeOfType(typeof(TempAndFan));
      tempAndFan.Should().BeEquivalentTo(inTempAndFanTestData.TempAndFan);
    }

    [Theory]
    [MemberData(nameof(TempAndFanTestDataGenerator.TempAndFanTestData), MemberType = typeof(TempAndFanTestDataGenerator))]
    public void TempAndFanSerializeToJSON(TempAndFanTestData inTempAndFanTestData)
    {
      var serializedTempAndFan = Fixture.Serializer.Serialize(inTempAndFanTestData.TempAndFan);
      serializedTempAndFan.Should().Be(inTempAndFanTestData.SerializedTempAndFan);
    }

    [Theory]
    [MemberData(nameof(TempAndFanArrayTestDataGenerator.TempAndFanArrayTestData), MemberType = typeof(TempAndFanArrayTestDataGenerator))]
    public void TempAndFanArrayDeserializeFromJSON(TempAndFanArrayTestData inTempAndFanArrayTestData)
    {
      var tempAndFanArray = Fixture.Serializer.Deserialize<TempAndFan[]>(inTempAndFanArrayTestData.SerializedTempAndFanArray);
      tempAndFanArray.Should().BeOfType(typeof(TempAndFan));
      tempAndFanArray.Should().BeEquivalentTo(inTempAndFanArrayTestData.TempAndFanArray);
    }

    [Theory]
    [MemberData(nameof(TempAndFanArrayTestDataGenerator.TempAndFanArrayTestData), MemberType = typeof(TempAndFanArrayTestDataGenerator))]
    public void TempAndFanArraySerializeToJSON(TempAndFanArrayTestData inTempAndFanArrayTestData)
    {
      var serializedTempAndFanArray = Fixture.Serializer.Serialize(inTempAndFanArrayTestData.TempAndFanArray);
      serializedTempAndFanArray.Should().Be(inTempAndFanArrayTestData.SerializedTempAndFanArray);
    }

    [Theory]
    [MemberData(nameof(VideoCardSignilTestDataGenerator.VideoCardSignilTestData), MemberType = typeof(VideoCardSignilTestDataGenerator))]
    public void VideoCardSignilDeserializeFromJSON(VideoCardSignilTestData inVideoCardSignilTestData)
    {
      var videoCardSignil = Fixture.Serializer.Deserialize<IVideoCardSignil>(inVideoCardSignilTestData.SerializedVideoCardSignil);
      videoCardSignil.Should().BeOfType(typeof(VideoCard));
      videoCardSignil.Should().Be(inVideoCardSignilTestData.VideoCardSignil);
    }


    [Theory]
    [MemberData(nameof(VideoCardTestDataGenerator.VideoCardTestData), MemberType = typeof(VideoCardTestDataGenerator))]
    public void VideoCardDeserializeFromJSON(VideoCardTestData inVideoCardTestData)
    {
      var videoCard = Fixture.Serializer.Deserialize<VideoCard>(inVideoCardTestData.SerializedVideoCard);
      videoCard.Should().BeOfType(typeof(VideoCard));
      videoCard.Should().Be(inVideoCardTestData.VideoCard);
    }

    [Theory]
    [MemberData(nameof(VideoCardTestDataGenerator.VideoCardTestData), MemberType = typeof(VideoCardTestDataGenerator))]
    internal void VideoCardSerializeToJSON(VideoCardTestData inVideoCardTestData)
    {
      Fixture.Serializer.Serialize(inVideoCardTestData.VideoCard).Should().Be(inVideoCardTestData.SerializedVideoCard);
    }

    [Theory]
    [MemberData(nameof(MainBoardTestDataGenerator.MainBoardTestData), MemberType = typeof(MainBoardTestDataGenerator))]
    internal void MainBoardSerializeToJSON(MainBoardTestData inMainBoardTestData)
    {
      Fixture.Serializer.Serialize(inMainBoardTestData.MainBoard).Should().Be(inMainBoardTestData.SerializedMainBoard);
    }
    [Theory]
    [MemberData(nameof(MainBoardTestDataGenerator.MainBoardTestData), MemberType = typeof(MainBoardTestDataGenerator))]
    public void MainBoardDeserializeFromJSON(MainBoardTestData inMainBoardTestData)
    {
      /*
      var mainBoard;
      Func<MainBoardTestData, MainBoard> deserialzeAction = (inMainBoardTestData) =>
      {
        return Fixture.Serializer.Deserialize<MainBoard>(inMainBoardTestData.SerializedMainBoard);
      };
      deserialzeAction.Should().NotThrow();
      */
      var mainBoard = Fixture.Serializer.Deserialize<MainBoard>(inMainBoardTestData.SerializedMainBoard); 
      mainBoard.Should().BeOfType(typeof(MainBoard));
      mainBoard.Should().Be(inMainBoardTestData.MainBoard);

    }


  }
}
