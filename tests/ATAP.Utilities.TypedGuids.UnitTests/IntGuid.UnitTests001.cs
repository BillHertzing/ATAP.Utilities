
using System;
using System.Collections;
using System.Collections.Generic;
using ATAP.Utilities.Testing;
using ATAP.Utilities.StronglyTypedIDs;
using FluentAssertions;
using Xunit;
using Xunit.Abstractions;


namespace ATAP.Utilities.StronglyTypedIDs.UnitTests
{

  public partial class IntGuidUnitTests001 : IClassFixture<Fixture>
  {

    [Theory]
    [MemberData(nameof(IntGuidTestDataGenerator.IntGuidTestData), MemberType = typeof(IntGuidTestDataGenerator))]
    public void IntGuidDeserializeFromJSON(IntGuidTestData inIntGuidTestData)
    {
      if (inIntGuidTestData.IntGuid.ToString().StartsWith("0000") | inIntGuidTestData.IntGuid.ToString().StartsWith("01234"))
      {
        var intID = Fixture.Serializer.Deserialize<IdAsStruct<int>>(inIntGuidTestData.SerializedIntGuid);
        intID.Should().BeOfType(typeof(IdAsStruct<int>));
        // GUIDS are random, two sets of test data have fixed, non-random guids, the rest are random
        Fixture.Serializer.Deserialize<IdAsStruct<int>>(inIntGuidTestData.SerializedIntGuid).Should().Be(inIntGuidTestData.IntGuid);
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
      var nameOfShim = Fixture.Serializer.ToString();
      TestOutput.WriteLine("DiFixture.Serializer = {0}", nameOfShim);
      // GUIDS are random, two sets of test data have fixed, non-random guids, the rest are random
      if (inIntGuidTestData.IntGuid.ToString().StartsWith("0000") | inIntGuidTestData.IntGuid.ToString().StartsWith("01234"))
      {
        Fixture.Serializer.Serialize(inIntGuidTestData.IntGuid).Should().Be(inIntGuidTestData.SerializedIntGuid);
      }
      else
      {
        // ServiceStack Shim serializes this structure with a preceding and trailing doublequote ("guid")
        Fixture.Serializer.Serialize(inIntGuidTestData.IntGuid).Should().MatchRegex("^\"[0-9A-Fa-f]{8}-?([0-9A-Fa-f]{4}-?){3}[0-9A-Fa-f]{12}\"$");
      }
    }


  }
}
