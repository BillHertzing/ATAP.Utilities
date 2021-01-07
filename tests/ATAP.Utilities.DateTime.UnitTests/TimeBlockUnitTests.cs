


using ATAP.Utilities.Testing;
using FluentAssertions;
using Itenso.TimePeriod;
using Xunit;
using Xunit.Abstractions;

namespace ATAP.Utilities.DateTime.UnitTests
{


  public partial class DateTimeUnitTests001 : IClassFixture<Fixture>
  {
    [Theory]
    [MemberData(nameof(TimeBlockTestDataGenerator.TestData), MemberType = typeof(TimeBlockTestDataGenerator))]
    public void TimeBlockDeserializeFromJSON(TimeBlockTestData inTestData)
    {
      var obj = Fixture.Serializer.Deserialize<TimeBlock>(inTestData.SerializedTestData);
      obj.Should().BeOfType(typeof(TimeBlock));
      Fixture.Serializer.Deserialize<TimeBlock>(inTestData.SerializedTestData).Should().BeEquivalentTo(inTestData.ObjTestData);
    }

    [Theory]
    [MemberData(nameof(TimeBlockTestDataGenerator.TestData), MemberType = typeof(TimeBlockTestDataGenerator))]
    public void TimeBlockSerializeToJSON(TimeBlockTestData inTestData)
    {
      Fixture.Serializer.Serialize(inTestData.ObjTestData).Should().Be(inTestData.SerializedTestData);
    }
  }
}
