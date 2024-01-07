using System;
using Xunit;
using ATAP.Utilities.Images.Enumerations;
using FluentAssertions;
using Xunit.Abstractions;
using ATAP.Utilities.Testing;

namespace ATAP.Utilities.Images.Enumerations.UnitTests
{

  public partial class EnumerationsUnitTests001 : IClassFixture<Fixture>
  {

    [Theory]
    [MemberData(nameof(DefaultEnumerationsTestDataGenerator.DefaultEnumerationsTestData), MemberType = typeof(DefaultEnumerationsTestDataGenerator))]
    public void DefaultEnumerationSerializeToJSON(DefaultEnumerationsTestData inDefaultEnumerationsTestData)
    {
      string str = DiFixture.Serializer.Serialize(DefaultEnumerations.Production);
      // TestOutput.WriteLine(str);
      str.Should().Be(inDefaultEnumerationsTestData.SerializedDefaultEnumerations);
    }

    // ToDo: Add more tests for Enumerations serialization

  }
}
