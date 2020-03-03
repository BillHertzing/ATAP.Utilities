using System;
using Xunit;
using ATAP.Utilities.ComputerInventory.Configuration;
using FluentAssertions;
using Xunit.Abstractions;
using ATAP.Utilities.Testing;

namespace ATAP.Utilities.ComputerInventory.UnitTests
{

  public class ComputerInventoryConfigurationUnitTests001 : IClassFixture<Fixture>
  {

    protected Fixture Fixture { get; }
    protected ITestOutputHelper TestOutput { get; }

    public ComputerInventoryConfigurationUnitTests001(ITestOutputHelper testOutput, Fixture fixture)
    {
      Fixture = fixture;
      TestOutput = testOutput;
    }

    [Theory]
    [MemberData(nameof(DefaultConfigurationTestDataGenerator.DefaultConfigurationTestData), MemberType = typeof(DefaultConfigurationTestDataGenerator))]
    public void DefaultConfigurationSerializeToJSON(DefaultConfigurationTestData inDefaultConfigurationTestData)
    {
      string str = Fixture.Serializer.Serialize(DefaultConfiguration.Production);
      // TestOutput.WriteLine(str);
      str.Should().Be(inDefaultConfigurationTestData.SerializedDefaultConfiguration);
    }



    // ToDo: Add more tests for default configuration

  }
}
