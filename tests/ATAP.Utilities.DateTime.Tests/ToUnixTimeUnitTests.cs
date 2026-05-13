


using ATAP.Utilities.Testing;
using FluentAssertions;
using Xunit;
using Xunit.Abstractions;

namespace ATAP.Utilities.DateTime.UnitTests
{


  public partial class DateTimeUnitTests001 : IClassFixture<Fixture>
  {
    /*
      [Theory]

    [InlineData(2000, 1, 1, 100000, 9467100)]
    // Test ToUnixTime
    public void ConvertToUnixTime(int inYear, int inMonth, int inDay, int inUnixUOM, int inExpectedUnixTime)
    {
      long result = ATAP.Utilities.DateTime.Utilities.ToUnixTime(new System.DateTime(inYear, inMonth, inDay), inUnixUOM);
      result.Should().Be(inExpectedUnixTime);
    }

    [Theory]
    [MemberData(nameof(ToUnixTimeTestDataGenerator.TestData), MemberType = typeof(ToUnixTimeTestDataGenerator))]
    public void UnitsNetInformationDeserializeFromJSON(UnitsNetInformationTestData inTestData)
    {
      var obj = DiFixture.DateTime.Deserialize<UnitsNet.Information>(inTestData.SerializedTestData);
      obj.Should().BeOfType(typeof(UnitsNet.Information));
      DiFixture.DateTime.Deserialize<UnitsNet.Information>(inTestData.SerializedTestData).Should().BeEquivalentTo(inTestData.ObjTestData);
    }

    [Theory]
    [MemberData(nameof(ToUnixTimeTestDataGenerator.TestData), MemberType = typeof(ToUnixTimeTestDataGenerator))]
    public void UnitsNetInformationSerializeToJSON(UnitsNetInformationTestData inTestData)
    {
      DiFixture.DateTime.Serialize(inTestData.ObjTestData).Should().Be(inTestData.SerializedTestData);
    }
    */
  }
}
