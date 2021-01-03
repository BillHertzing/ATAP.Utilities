using System;
using Xunit;
using ATAP.Utilities.ComputerInventory.Configuration;
using FluentAssertions;
using Xunit.Abstractions;
using ATAP.Utilities.Testing;

namespace ATAP.Utilities.ComputerInventory.Configuration.UnitTests
{

  public partial class ComputerInventoryConfigurationUnitTests001 : IClassFixture<ComputerInventoryConfigurationFixture>
  {

    /*
    [Theory]
    [MemberData(nameof(DefaultConfigurationTestDataGenerator.DefaultConfigurationTestData), MemberType = typeof(DefaultConfigurationTestDataGenerator))]
    public void DefaultConfigurationSerializeToJSON(DefaultConfigurationTestData inDefaultConfigurationTestData)
    {
      string str = DiFixture.Serializer.Serialize(DefaultConfiguration.Production);
      // TestOutput.WriteLine(str);
      str.Should().Be(inDefaultConfigurationTestData.SerializedDefaultConfiguration);
    }
    */


    // ToDo: Add more tests for default configuration

  }
}
