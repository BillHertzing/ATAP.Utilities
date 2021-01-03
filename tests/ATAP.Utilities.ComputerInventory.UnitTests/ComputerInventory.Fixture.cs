

using ATAP.Utilities.Testing;
using FluentAssertions;
using Xunit;
using Xunit.Abstractions;


namespace ATAP.Utilities.ComputerInventory.UnitTests
{
  public class ComputerInventoryFixture : DiFixture { }
  public partial class ComputerInventoryUnitTests001 : IClassFixture<ComputerInventoryFixture>
  {
    protected ComputerInventoryFixture Fixture { get; }
    protected ITestOutputHelper TestOutput { get; }

    public ComputerInventoryUnitTests001(ITestOutputHelper testOutput, ComputerInventoryFixture fixture)
    {
      Fixture = fixture;
      TestOutput = testOutput;
    }



  }
}
