

using ATAP.Utilities.Testing;
using FluentAssertions;
using Xunit;
using Xunit.Abstractions;


namespace ATAP.Utilities.ComputerInventory.Software.UnitTests
{
  public class ComputerInventorySoftwareFixture : Fixture { }
  public partial class ComputerInventorySoftwareUnitTests001 : IClassFixture<ComputerInventorySoftwareFixture>
  {
    protected ComputerInventorySoftwareFixture Fixture { get; }
    protected ITestOutputHelper TestOutput { get; }

    public ComputerInventorySoftwareUnitTests001(ITestOutputHelper testOutput, ComputerInventorySoftwareFixture fixture)
    {
      Fixture = fixture;
      TestOutput = testOutput;
    }



  }
}
