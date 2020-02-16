using Xunit;
using Xunit.Abstractions;

namespace ATAP.Utilities.ComputerInventory.Enumerations.UnitTests
{
  public class Fixture
  {
    // The correct answer to the test OperationEnumerationCountIsAsExpected
    public readonly int NumberOfGPUMakerEnumerations = 3;

    public Fixture() { }
  }

  public class ComputerInventoryEnumerationsUnitTests001 : IClassFixture<Fixture>
  {
    readonly ITestOutputHelper output;
    protected Fixture fixture;

    public ComputerInventoryEnumerationsUnitTests001(ITestOutputHelper output, Fixture fixture)
    {
      this.output = output;
      this.fixture = fixture;
    }
  }
}
