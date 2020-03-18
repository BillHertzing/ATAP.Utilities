


using ATAP.Utilities.Testing;
using FluentAssertions;
using Itenso.TimePeriod;
using System.Collections.Generic;
using Xunit;
using Xunit.Abstractions;
using System.Linq;

namespace ATAP.Utilities.DateTime.UnitTests
{


  public partial class DateTimeUnitTests001 : IClassFixture<DateTimeFixture>
  {
    [Theory]
    [MemberData(nameof(TimeBlockEnumerableTestDataGenerator.TestData), MemberType = typeof(TimeBlockEnumerableTestDataGenerator))]
    public void TimeBlockEnumerableDeserializeFromJSON(TimeBlockEnumerableTestData inTestData)
    {
      foreach (var itb in inTestData.E)
      {
        var obj = Fixture.Serializer.Deserialize<IEnumerable<ITimeBlock>>(itb.SerializedTestData) ;
        obj.Should().BeOfType(typeof(IEnumerable<ITimeBlock>));
        Fixture.Serializer.Deserialize<IEnumerable<ITimeBlock>>(itb.SerializedTestData).Should().BeEquivalentTo(itb.ObjTestData);
      }

      // ToDo loop over every element of the enumerable and test eah one

    }

    [Theory]
    [MemberData(nameof(TimeBlockEnumerableTestDataGenerator.TestData), MemberType = typeof(TimeBlockEnumerableTestDataGenerator))]
    public void TimeBlockEnumerableSerializeToJSON(TimeBlockEnumerableTestData inTestData)
    {
#if DEBUG
      TestOutput.WriteLine("Starting " + nameof(TimeBlockEnumerableSerializeToJSON));
#endif
      foreach (var e in inTestData.E)
      {
#if DEBUG
        TestOutput.WriteLine("SerializedTestData     is:" + e.SerializedTestData);
        TestOutput.WriteLine("Serialized ObjTestData is:" + Fixture.Serializer.Serialize(e.ObjTestData));
#endif
        Fixture.Serializer.Serialize(e.ObjTestData).Should().Be(e.SerializedTestData);
      }
    }
  }
}
