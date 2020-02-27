using Xunit;
using Xunit.Abstractions;

namespace ATAP.Utilities.ComputerInventory.Extensions.UnitTests
{
  public class Fixture
  {
    public Fixture()
    {
    }
  }

  public class ComputerInventoryExtensionsUnitTests001 : IClassFixture<Fixture>
  {
    readonly ITestOutputHelper output;
    protected Fixture fixture;

    public ComputerInventoryExtensionsUnitTests001(ITestOutputHelper output, Fixture fixture)
    {
      this.output = output;
      this.fixture = fixture;
    }
  }
}
