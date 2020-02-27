using System;
using Xunit;
using ATAP.Utilities.ComputerInventory.Configuration;
using FluentAssertions;
using Xunit.Abstractions;

namespace ATAP.Utilities.ComputerInventory.Configuration.UnitTests
{
  public class Fixture
  {
    ITestOutputHelper TestOutput { get; }

    public Fixture()
    {
      // dcsUnderTest = new DefaultConfigurationSettings();

      //    new EnumSerializerConfigurator()
      //.WithAssemblies(AppDomain.CurrentDomain.GetAssemblies())
      //.WithNamespaceFilter(ns => ns.StartsWith("ATAP"))
      //.Configure();
    }
    public Fixture(ITestOutputHelper testOutput)
    {
      TestOutput = testOutput;
      // dcsUnderTest = new DefaultConfigurationSettings();

      //    new EnumSerializerConfigurator()
      //.WithAssemblies(AppDomain.CurrentDomain.GetAssemblies())
      //.WithNamespaceFilter(ns => ns.StartsWith("ATAP"))
      //.Configure();
    }
  }

  public class ComputerInventoryConfigurationUnitTests001 : IClassFixture<Fixture>
  {

    readonly ITestOutputHelper output;
    protected Fixture Fixture { get; }
    public ComputerInventoryConfigurationUnitTests001(ITestOutputHelper output, Fixture fixture)
    {
      this.output = output;
      Fixture = fixture;
    }

      [Theory]
      [InlineData("{\"ComputerSoftwareProgram\":{\"ProcessName\":powershell}}")]
      public void DefaultConfigurationSettingsAsExpected(params string[] _testdatainput)
      {
        output.WriteLine("test {0}", "DefaultConfigurationSettingsAsExpected");
      ATAP.Utilities.ComputerInventory.Configuration.DefaultConfigurationSettings.Dcs.Should().HaveCount(1, "Because we're just getting started");
        DefaultConfigurationSettings.Dcs.ToString().Should().Match(_testdatainput[0]);
      }
   
  }
}
