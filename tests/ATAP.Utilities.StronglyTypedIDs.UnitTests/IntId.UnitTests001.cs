
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

  public partial class IntIdUnitTests001 : IClassFixture<Fixture>
  {

    [Theory]
    [MemberData(nameof(IntIdTestDataGenerator.IntIdTestData), MemberType = typeof(IntIdTestDataGenerator))]
    public void IntIdDeserializeFromJSON(IntIdTestData inIntIdTestData)
    {
      if (inIntIdTestData.IntId.ToString().StartsWith("0000") | inIntIdTestData.IntId.ToString().StartsWith("01234"))
      {
        var intID = Fixture.Serializer.Deserialize<IntStronglyTypedID>(inIntIdTestData.SerializedIntId);
        intID.Should().BeOfType(typeof(IdAsStruct<int>));
        // GUIDS are random, two sets of test data have fixed, non-random guids, the rest are random
        Fixture.Serializer.Deserialize<IdAsStruct<int>>(inIntIdTestData.SerializedIntId).Should().Be(inIntIdTestData.IntId);
      }
      else
      {
        // No data for random guids
      }
    }

    [Theory]
    [MemberData(nameof(IntIdTestDataGenerator.IntIdTestData), MemberType = typeof(IntIdTestDataGenerator))]
    public void IntIdSerializeToJSON(IntIdTestData inIntIdTestData)
    {
      var nameOfShim = Fixture.Serializer.ToString();
      TestOutput.WriteLine("DiFixture.Serializer = {0}", nameOfShim);
      // GUIDS are random, two sets of test data have fixed, non-random guids, the rest are random
      if (inIntIdTestData.IntId.ToString().StartsWith("0000") | inIntIdTestData.IntId.ToString().StartsWith("01234"))
      {
        Fixture.Serializer.Serialize(inIntIdTestData.IntId).Should().Be(inIntIdTestData.SerializedIntId);
      }
      else
      {
        // ServiceStack Shim serializes this structure with a preceding and trailing doublequote ("guid")
        Fixture.Serializer.Serialize(inIntIdTestData.IntId).Should().MatchRegex("^\"[0-9A-Fa-f]{8}-?([0-9A-Fa-f]{4}-?){3}[0-9A-Fa-f]{12}\"$");
      }
    }


  }
}
