
using System;
using System.Collections;
using System.Collections.Generic;
using ATAP.Utilities.Testing;
using ATAP.Utilities.StronglyTypedID;
using FluentAssertions;
using Xunit;
using Xunit.Abstractions;


namespace ATAP.Utilities.StronglyTypedID.UnitTests
{

  public partial class GuidIdUnitTests001 : IClassFixture<Fixture>
  {

    [Theory]
    [MemberData(nameof(GuidIdTestDataGenerator.GuidIdTestData), MemberType = typeof(GuidIdTestDataGenerator))]
    public void GuidIdDeserializeFromJSON(GuidIdTestData inGuidIdTestData)
    {
      if (inGuidIdTestData.GuidId.ToString().StartsWith("0000") | inGuidIdTestData.GuidId.ToString().StartsWith("01234"))
      {
        var GuidId = Fixture.Serializer.Deserialize<GuidStronglyTypedID>(inGuidIdTestData.SerializedGuidId);
        GuidId.Should().BeOfType(typeof(GuidStronglyTypedID));
        // GUIDS are random, two sets of test data have fixed, non-random guids, the rest are random
        Fixture.Serializer.Deserialize<GuidStronglyTypedID>(inGuidIdTestData.SerializedGuidId).Should().Be(inGuidIdTestData.GuidId);
      }
      else
      {
        // No data for random guids
      }
    }

    [Theory]
    [MemberData(nameof(GuidIdTestDataGenerator.GuidIdTestData), MemberType = typeof(GuidIdTestDataGenerator))]
    public void GuidIdSerializeToJSON(GuidIdTestData inGuidIdTestData)
    {
      var nameOfShim = Fixture.Serializer.ToString();
      TestOutput.WriteLine("DiFixture.Serializer = {0}", nameOfShim);
      // GUIDS are random, two sets of test data have fixed, non-random guids, the rest are random
      if (inGuidIdTestData.GuidId.ToString().StartsWith("0000") | inGuidIdTestData.GuidId.ToString().StartsWith("01234"))
      {
        Fixture.Serializer.Serialize(inGuidIdTestData.GuidId).Should().Be(inGuidIdTestData.SerializedGuidId);
      }
      else
      {
        // ServiceStack Shim serializes this structure with a preceding and trailing doublequote ("guid")
        Fixture.Serializer.Serialize(inGuidIdTestData.GuidId).Should().MatchRegex("^\"[0-9A-Fa-f]{8}-?([0-9A-Fa-f]{4}-?){3}[0-9A-Fa-f]{12}\"$");
      }
    }


  }
}
