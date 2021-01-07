using System;
using System.Text;
using System.Collections.Generic;
using System.Linq;
using System.Timers;
using FluentAssertions;
using Xunit;
using Xunit.Abstractions;
using ServiceStack.Text;
using ATAP.Utilities.ComputerInventory;
using ATAP.Utilities.ComputerInventory.Hardware;
using ATAP.Utilities.Testing;
using Itenso.TimePeriod;

namespace ATAP.Utilities.ComputerInventory.Hardware.UnitTests
{

  public partial class ComputerInventoryHardwareUnitTests001 : IClassFixture<Fixture>
  {

    [Theory]
    [MemberData(nameof(PowerConsumptionTestDataGenerator.PowerConsumptionTestData), MemberType = typeof(PowerConsumptionTestDataGenerator))]
    public void PowerConsumptionDeserializeFromJSON(PowerConsumptionTestData inTestData)
    {
      var powerConsumption = Fixture.Serializer.Deserialize<PowerConsumption>(inTestData.SerializedPowerConsumption);
      powerConsumption.Should().BeOfType(typeof(PowerConsumption));
      powerConsumption.Should().Be(inTestData.PowerConsumption);
    }

    [Theory]
    [MemberData(nameof(PowerConsumptionTestDataGenerator.PowerConsumptionTestData), MemberType = typeof(PowerConsumptionTestDataGenerator))]
    public void PowerConsumptionSerializeToJSON(PowerConsumptionTestData inTestData)
    {
      string str = Fixture.Serializer.Serialize(inTestData.PowerConsumption);
      str.Should().Be(inTestData.SerializedPowerConsumption);
    }

    [Theory]
    [MemberData(nameof(TempAndFanTestDataGenerator.TempAndFanTestData), MemberType = typeof(TempAndFanTestDataGenerator))]
    public void TempAndFanDeserializeFromJSON(TempAndFanTestData inTestData)
    {
      var tempAndFan = Fixture.Serializer.Deserialize<TempAndFan>(inTestData.SerializedTempAndFan);
      tempAndFan.Should().BeOfType(typeof(TempAndFan));
      tempAndFan.Should().BeEquivalentTo(inTestData.TempAndFan);
    }

    [Theory]
    [MemberData(nameof(TempAndFanTestDataGenerator.TempAndFanTestData), MemberType = typeof(TempAndFanTestDataGenerator))]
    public void TempAndFanSerializeToJSON(TempAndFanTestData inTestData)
    {
      var serializedTempAndFan = Fixture.Serializer.Serialize(inTestData.TempAndFan);
      serializedTempAndFan.Should().Be(inTestData.SerializedTempAndFan);
    }

    [Theory]
    [MemberData(nameof(TempAndFanArrayTestDataGenerator.TempAndFanArrayTestData), MemberType = typeof(TempAndFanArrayTestDataGenerator))]
    public void TempAndFanArrayDeserializeFromJSON(TempAndFanArrayTestData inTestData)
    {
      var tempAndFanArray = Fixture.Serializer.Deserialize<TempAndFan[]>(inTestData.SerializedTempAndFanArray);
      tempAndFanArray.Should().BeOfType(typeof(TempAndFan));
      tempAndFanArray.Should().BeEquivalentTo(inTestData.TempAndFanArray);
    }

    [Theory]
    [MemberData(nameof(TempAndFanArrayTestDataGenerator.TempAndFanArrayTestData), MemberType = typeof(TempAndFanArrayTestDataGenerator))]
    public void TempAndFanArraySerializeToJSON(TempAndFanArrayTestData inTestData)
    {
      var serializedTempAndFanArray = Fixture.Serializer.Serialize(inTestData.TempAndFanArray);
      serializedTempAndFanArray.Should().Be(inTestData.SerializedTempAndFanArray);
    }

    [Theory]
    [MemberData(nameof(VideoCardSignilTestDataGenerator.VideoCardSignilTestData), MemberType = typeof(VideoCardSignilTestDataGenerator))]
    public void VideoCardSignilSerializeToJSON(VideoCardSignilTestData inTestData)
    {
      var serializedVideoCardSignil = Fixture.Serializer.Serialize(inTestData.VideoCardSignil);
      serializedVideoCardSignil.Should().Be(inTestData.SerializedVideoCardSignil);
    }

    [Theory]
    [MemberData(nameof(VideoCardSignilTestDataGenerator.VideoCardSignilTestData), MemberType = typeof(VideoCardSignilTestDataGenerator))]
    public void VideoCardSignilDeserializeFromJSON(VideoCardSignilTestData inTestData)
    {
      var videoCardSignil = Fixture.Serializer.Deserialize<IVideoCardSignil>(inTestData.SerializedVideoCardSignil);
      videoCardSignil.Should().BeOfType(typeof(VideoCard));
      videoCardSignil.Should().Be(inTestData.VideoCardSignil);
    }

    [Theory]
    [MemberData(nameof(VideoCardTestDataGenerator.VideoCardTestData), MemberType = typeof(VideoCardTestDataGenerator))]
    public void VideoCardDeserializeFromJSON(VideoCardTestData inTestData)
    {
      var videoCard = Fixture.Serializer.Deserialize<VideoCard>(inTestData.SerializedVideoCard);
      videoCard.Should().BeOfType(typeof(VideoCard));
      videoCard.Should().Be(inTestData.VideoCard);
    }

    [Theory]
    [MemberData(nameof(VideoCardTestDataGenerator.VideoCardTestData), MemberType = typeof(VideoCardTestDataGenerator))]
    internal void VideoCardSerializeToJSON(VideoCardTestData inTestData)
    {
      Fixture.Serializer.Serialize(inTestData.VideoCard).Should().Be(inTestData.SerializedVideoCard);
    }

  }
}
