


using ATAP.Utilities.Testing;
using FluentAssertions;
using Xunit;
using Xunit.Abstractions;

namespace ATAP.Utilities.Serializer.UnitTests
{


  public partial class SerializerUnitTests001 : IClassFixture<Fixture>
  {
    [Theory]
    [MemberData(nameof(IntegerTestDataGenerator.TestData), MemberType = typeof(IntegerTestDataGenerator))]
    public void IntegerDeserializeFromJSON(IntegerTestData inTestData)
    {
      var obj = Fixture.Serializer.Deserialize<System.Int32>(inTestData.SerializedTestData);
      obj.Should().BeOfType(typeof(System.Int32));
      Fixture.Serializer.Deserialize<System.Int32>(inTestData.SerializedTestData).Should().Equals(inTestData.ObjTestData);
    }

    [Theory]
    [MemberData(nameof(IntegerTestDataGenerator.TestData), MemberType = typeof(IntegerTestDataGenerator))]
    public void IntegerSerializeToJSON(IntegerTestData inTestData)
    {
      Fixture.Serializer.Serialize(inTestData.ObjTestData).Should().Be(inTestData.SerializedTestData);
    }
  }
}
