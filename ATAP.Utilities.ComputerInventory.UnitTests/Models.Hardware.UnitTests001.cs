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

namespace ATAP.Utilities.ComputerInventory.Configuration.UnitTests
{

  public class ModelsHardwareUnitTests001 : IClassFixture<Fixture>
  {
    protected Fixture Fixture { get; }
    protected ITestOutputHelper TestOutput { get; }

    public ModelsHardwareUnitTests001(ITestOutputHelper testOutput, Fixture fixture)
    {
      Fixture = fixture;
      TestOutput = testOutput;
    }

    [Theory]
    [MemberData(nameof(CPUTestDataGenerator.CPUTestData), MemberType = typeof(CPUTestDataGenerator))]
    public void CPUDeserializeFromJSON(CPUTestData inCPUTestData)
    {
      CPU cPU = JsonSerializer.DeserializeFromString<CPU>(inCPUTestData.SerializedCPU);
      TestOutput.WriteLine(cPU.CPUMaker.ToString());
      JsonSerializer.DeserializeFromString<CPU>(inCPUTestData.SerializedCPU).Should().Be(inCPUTestData.CPU);
    }

    [Theory]
    [MemberData(nameof(CPUTestDataGenerator.CPUTestData), MemberType = typeof(CPUTestDataGenerator))]
    public void CPUSerializeToJSON(CPUTestData inCPUTestData)
    {
      string str = JsonSerializer.SerializeToString(inCPUTestData.CPU);
      TestOutput.WriteLine(str);
      JsonSerializer.SerializeToString(inCPUTestData.CPU).Should().Be(inCPUTestData.SerializedCPU);
    }

    [Theory]
    [MemberData(nameof(CPUArrayTestDataGenerator.CPUArrayTestData), MemberType = typeof(CPUArrayTestDataGenerator))]
    public void CPUArrayDeserializeFromJSON(CPUArrayTestData inCPUArrayTestData)
    {
      CPU[] cPUArray = JsonSerializer.DeserializeFromString<CPU[]>(inCPUArrayTestData.SerializedCPUArray);
      cPUArray.Should().BeEquivalentTo(inCPUArrayTestData.CPUArray);
    }

    [Theory]
    [MemberData(nameof(CPUArrayTestDataGenerator.CPUArrayTestData), MemberType = typeof(CPUArrayTestDataGenerator))]
    public void CPUArraySerializeToJSON(CPUArrayTestData inCPUArrayTestData)
    {
      string str = JsonSerializer.SerializeToString(inCPUArrayTestData.CPUArray);
      str.Should().Be(inCPUArrayTestData.SerializedCPUArray);
    }

    [Theory]
    [MemberData(nameof(PowerConsumptionTestDataGenerator.PowerConsumptionTestData), MemberType = typeof(PowerConsumptionTestDataGenerator))]
    public void PowerConsumptionDeserializeFromJSON(PowerConsumptionTestData inPowerConsumptionTestData)
    {
      PowerConsumption powerConsumption = JsonSerializer.DeserializeFromString<PowerConsumption>(inPowerConsumptionTestData.SerializedPowerConsumption);
      powerConsumption.Should().Be(inPowerConsumptionTestData.PowerConsumption);
    }

    [Theory]
    [MemberData(nameof(PowerConsumptionTestDataGenerator.PowerConsumptionTestData), MemberType = typeof(PowerConsumptionTestDataGenerator))]
    public void PowerConsumptionSerializeToJSON(PowerConsumptionTestData inPowerConsumptionTestData)
    {
      string str = JsonSerializer.SerializeToString(inPowerConsumptionTestData.SerializedPowerConsumption);
      str.Should().Be(inPowerConsumptionTestData.SerializedPowerConsumption);
    }

    [Theory]
    [MemberData(nameof(TempAndFanTestDataGenerator.TempAndFanTestData), MemberType = typeof(TempAndFanTestDataGenerator))]
    public void TempAndFanDeserializeFromJSON(TempAndFanTestData inTempAndFanTestData)
    {
      var tempAndFan = JsonSerializer.DeserializeFromString<TempAndFan>(inTempAndFanTestData.SerializedTempAndFan);
      tempAndFan.Should().BeEquivalentTo(inTempAndFanTestData.TempAndFan);
    }

    [Theory]
    [MemberData(nameof(TempAndFanTestDataGenerator.TempAndFanTestData), MemberType = typeof(TempAndFanTestDataGenerator))]
    public void TempAndFanSerializeToJSON(TempAndFanTestData inTempAndFanTestData)
    {
      var serializedTempAndFan = JsonSerializer.SerializeToString<TempAndFan>(inTempAndFanTestData.TempAndFan);
      serializedTempAndFan.Should().Be(inTempAndFanTestData.SerializedTempAndFan);
    }

    [Theory]
    [MemberData(nameof(TempAndFanArrayTestDataGenerator.TempAndFanArrayTestData), MemberType = typeof(TempAndFanArrayTestDataGenerator))]
    public void TempAndFanArrayDeserializeFromJSON(TempAndFanArrayTestData inTempAndFanArrayTestData)
    {
      var tempAndFanArray = JsonSerializer.DeserializeFromString<TempAndFan[]>(inTempAndFanArrayTestData.SerializedTempAndFanArray);
      tempAndFanArray.Should().BeEquivalentTo(inTempAndFanArrayTestData.TempAndFanArray);
    }

    [Theory]
    [MemberData(nameof(TempAndFanArrayTestDataGenerator.TempAndFanArrayTestData), MemberType = typeof(TempAndFanArrayTestDataGenerator))]
    public void TempAndFanArraySerializeToJSON(TempAndFanArrayTestData inTempAndFanArrayTestData)
    {
      using (JsConfig.With(new Config { TextCase = TextCase.PascalCase }))
      {
        var serializedTempAndFanArray = JsonSerializer.SerializeToString<TempAndFan[]>(inTempAndFanArrayTestData.TempAndFanArray);
        serializedTempAndFanArray.Should().Be(inTempAndFanArrayTestData.SerializedTempAndFanArray);
      }
    }

    [Theory]
    [MemberData(nameof(VideoCardTestDataGenerator.VideoCardTestData), MemberType = typeof(VideoCardTestDataGenerator))]
    public void VideoCardDeserializeFromJSON(VideoCardTestData inVideoCardTestData)
    {
      //VideoCard videoCard = JsonSerializer.DeserializeFromString<VideoCard>(inVideoCardTestData.SerializedVideoCard);
      //TestOutput.WriteLine(videoCard.BIOSVersion.ToString());
      JsonSerializer.DeserializeFromString<VideoCard>(inVideoCardTestData.SerializedVideoCard).Should().Be(inVideoCardTestData.VideoCard);
    }


    [Theory]
    [MemberData(nameof(VideoCardTestDataGenerator.VideoCardTestData), MemberType = typeof(VideoCardTestDataGenerator))]
    // [InlineData("{\"BIOSVersion\":\"100.00001.02320.00\",\"CoreClock\":1140.0,\"CoreVoltage\":11.13,\"DeviceID\":\"10DE 17C8 - 3842\",\"IsStrapped\":false,\"MemClock\":1753.0,\"PowerLimit\":0.8,\"VideoCardDiscriminatingCharacteristics\":{\"CardName\":\"GTX 980 TI\",\"GPUMaker\":\"NVIDEA\",\"VideoCardMaker\":\"ASUS\",\"VideoMemoryMaker\":\"Samsung\",\"VideoMemorySize\":6144}}")]
    internal void VideoCardSerializeToJSON(VideoCardTestData inVideoCardTestData)
    {
      JsonSerializer.SerializeToString<VideoCard>(inVideoCardTestData.VideoCard).Should().Be(inVideoCardTestData.SerializedVideoCard);
//      VideoCardDiscriminatingCharacteristics vcdc = VideoCardsKnownDefaultConfiguration.TuningParameters.Keys.Where(x => (x.VideoCardMaker ==
//VideoCardMaker.ASUS
//&& x.GPUMaker ==
//GPUMaker.NVIDEA))
//                                                        .Single();
//      VideoCard videoCard = new VideoCard(vcdc,
//                                          "10DE 17C8 - 3842",
//                                          "100.00001.02320.00",
//                                          false,
//                                          1140,
//                                          1753,
//                                          11.13,
//                                          0.8);
//      string str = JsonSerializer.SerializeToString(videoCard);
//      str.Should()
//          .NotBeNull();
//      str.Should()
//          .Be(_testdatainput);
    }

    [Theory]
    [MemberData(nameof(MainBoardTestDataGenerator.MainBoardTestData), MemberType = typeof(MainBoardTestDataGenerator))]
    internal void MainBoardSerializeToJSON(MainBoardTestData inMainBoardTestData)
    {
      JsonSerializer.SerializeToString<MainBoard>(inMainBoardTestData.MainBoard).Should().Be(inMainBoardTestData.SerializedMainBoard);
    }
    [Theory]
    [MemberData(nameof(MainBoardTestDataGenerator.MainBoardTestData), MemberType = typeof(MainBoardTestDataGenerator))]
    public void MainBoardDeserializeFromJSON(MainBoardTestData inMainBoardTestData)
    {
      JsonSerializer.DeserializeFromString<MainBoard>(inMainBoardTestData.SerializedMainBoard).Should().Be(inMainBoardTestData.MainBoard);

    }


  }
}
