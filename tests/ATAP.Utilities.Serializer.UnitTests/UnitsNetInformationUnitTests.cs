


using ATAP.Utilities.Testing;
using FluentAssertions;
using Xunit;
using Xunit.Abstractions;

namespace ATAP.Utilities.Serializer.UnitTests
{


  public partial class SerializerUnitTests001 : IClassFixture<Fixture>
  {
    [Theory]
    [MemberData(nameof(UnitsNetInformationTestDataGenerator.TestData), MemberType = typeof(UnitsNetInformationTestDataGenerator))]
    public void UnitsNetInformationDeserializeFromJSON(UnitsNetInformationTestData inTestData)
    {
      if (Fixture == null) { TestOutput.WriteLine("Fixture is null"); }
      if (Fixture.Serializer == null) { TestOutput.WriteLine("Fixture.Serializer is null"); }
      var obj = Fixture.Serializer.Deserialize<UnitsNet.Information>(inTestData.SerializedTestData);
      obj.Should().BeOfType(typeof(UnitsNet.Information));
      Fixture.Serializer.Deserialize<UnitsNet.Information>(inTestData.SerializedTestData).Should().BeEquivalentTo(inTestData.ObjTestData);
    }

    [Theory]
    [MemberData(nameof(UnitsNetInformationTestDataGenerator.TestData), MemberType = typeof(UnitsNetInformationTestDataGenerator))]
    public void UnitsNetInformationSerializeToJSON(UnitsNetInformationTestData inTestData)
    {
      Fixture.Serializer.Serialize(inTestData.ObjTestData).Should().Be(inTestData.SerializedTestData);
    }
  }
}
