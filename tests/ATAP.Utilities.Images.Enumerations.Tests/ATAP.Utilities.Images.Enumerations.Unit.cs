using System;
using Xunit;
using ATAP.Utilities.Images.Enumerations;
using FluentAssertions;
using Xunit.Abstractions;
using ATAP.Utilities.Testing;
using System.Text.Json;
using System.Collections.Generic;

namespace ATAP.Utilities.Images.Enumerations.Tests
{

  [Trait("Category", "Unit")]
  public partial class EnumerationsUnitTests001 : IClassFixture<Fixture>
  {

    [Theory]
    [MemberData(nameof(DefaultEnumerationsTestDataGenerator.DefaultEnumerationsTestData), MemberType = typeof(DefaultEnumerationsTestDataGenerator))]
    public void DefaultEnumerationSerializeToJSON(DefaultEnumerationsTestData inDefaultEnumerationsTestData)
    {
      string str = JsonSerializer.Serialize(DefaultEnumerations.Production);

      str.Should().Be(inDefaultEnumerationsTestData.SerializedDefaultEnumerations);

      JsonSerializer.Deserialize<Dictionary<string, int>>(str).Should().BeEquivalentTo(DefaultEnumerations.Production);
    }

    // ToDo: Add more tests for Enumerations serialization

  }
}
