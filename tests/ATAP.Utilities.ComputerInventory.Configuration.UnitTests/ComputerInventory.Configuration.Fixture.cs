
using System;
using ATAP.Utilities.Testing;
using FluentAssertions;
using Xunit;
using Xunit.Abstractions;


namespace ATAP.Utilities.ComputerInventory.Configuration.UnitTests
{
  public class ComputerInventoryConfigurationFixture : DiFixture { }
  public partial class ComputerInventoryConfigurationUnitTests001 : IClassFixture<ComputerInventoryConfigurationFixture>
  {
    protected ComputerInventoryConfigurationFixture Fixture { get; }
    protected ITestOutputHelper TestOutput { get; }

    public ComputerInventoryConfigurationUnitTests001(ITestOutputHelper testOutput, ComputerInventoryConfigurationFixture fixture)
    {
      Fixture = fixture;
      TestOutput = testOutput;
    }



  }
}
