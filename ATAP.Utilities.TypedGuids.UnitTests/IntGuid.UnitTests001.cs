

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
      if (inIntGuidTestData.IntGuid.ToString().StartsWith("0000") | inIntGuidTestData.IntGuid.ToString().StartsWith("01234"))
      {
        var intID = Fixture.Serializer.Deserialize<Id<int>>(inIntGuidTestData.SerializedIntGuid);
        intID.Should().BeOfType(typeof(Id<int>));
        // GUIDS are random, two sets of test data have fixed, non-random guids, the rest are random
        Fixture.Serializer.Deserialize<Id<int>>(inIntGuidTestData.SerializedIntGuid).Should().Be(inIntGuidTestData.IntGuid);
      }
      else
      {
        // No data for random guids
      }
    }

    [Theory]
    [MemberData(nameof(IntGuidTestDataGenerator.IntGuidTestData), MemberType = typeof(IntGuidTestDataGenerator))]
    public void IntGuidSerializeToJSON(IntGuidTestData inIntGuidTestData)
    {
      // GUIDS are random, two sets of test data have fixed, non-random guids, the rest are random
      if (inIntGuidTestData.IntGuid.ToString().StartsWith("0000") | inIntGuidTestData.IntGuid.ToString().StartsWith("01234"))
      {
        Fixture.Serializer.Serialize(inIntGuidTestData.IntGuid).Should().Be(inIntGuidTestData.SerializedIntGuid);
      }
      else
      {
        // ServiceStack Shim serialzes this structure with a preseend and training doublequote ("guid")
        Fixture.Serializer.Serialize(inIntGuidTestData.IntGuid).Should().MatchRegex("^\"[0-9A-Fa-f]{8}-?([0-9A-Fa-f]{4}-?){3}[0-9A-Fa-f]{12}\"$");
      }
    }


  }
}
