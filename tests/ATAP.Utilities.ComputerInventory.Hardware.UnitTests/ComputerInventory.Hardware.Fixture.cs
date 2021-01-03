

using ATAP.Utilities.Testing;
using FluentAssertions;
using Xunit;
using Xunit.Abstractions;


namespace ATAP.Utilities.ComputerInventory.Hardware.UnitTests
{
  public class ComputerInventoryHardwareFixture : DiFixture { }
  public partial class ComputerInventoryHardwareUnitTests001 : IClassFixture<ComputerInventoryHardwareFixture>
  {
    protected ComputerInventoryHardwareFixture Fixture { get; }
    protected ITestOutputHelper TestOutput { get; }

    public ComputerInventoryHardwareUnitTests001(ITestOutputHelper testOutput, ComputerInventoryHardwareFixture fixture)
    {
      Fixture = fixture;
      TestOutput = testOutput;
    }



  }
}
