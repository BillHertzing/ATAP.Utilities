

using ATAP.Utilities.Testing;
using ATAP.Utilities.TypedGuids;
using FluentAssertions;
using Xunit;
using Xunit.Abstractions;


namespace ATAP.Utilities.TypedGuids.UnitTests
{

  public class IntGuid_UnitTests001 : IClassFixture<Fixture>
  {
    protected Fixture Fixture { get; }
    protected ITestOutputHelper TestOutput { get; }

    public IntGuid_UnitTests001(ITestOutputHelper testOutput, Fixture fixture)
    {
      Fixture = fixture;
      TestOutput = testOutput;
    }

    [Theory]
    [MemberData(nameof(IntGuidTestDataGenerator.IntGuidTestData), MemberType = typeof(IntGuidTestDataGenerator))]
    public void IntGuidDeserializeFromJSON(IntGuidTestData inIntGuidTestData)
    {
      var intID = Fixture.Serializer.Deserialize<Id<int>>(inIntGuidTestData.SerializedIntGuid);
      intID.Should().BeOfType(typeof(Id<int>));
      Fixture.Serializer.Deserialize<Id<int>>(inIntGuidTestData.SerializedIntGuid).Should().Be(inIntGuidTestData.IntGuid);
    }

    [Theory]
    [MemberData(nameof(IntGuidTestDataGenerator.IntGuidTestData), MemberType = typeof(IntGuidTestDataGenerator))]
    public void IntGuidSerializeToJSON(IntGuidTestData inIntGuidTestData)
    {
      Fixture.Serializer.Serialize(inIntGuidTestData.IntGuid).Should().Be(inIntGuidTestData.SerializedIntGuid);
    }


  }
}
