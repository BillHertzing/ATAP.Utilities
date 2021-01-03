


using ATAP.Utilities.Testing;
using FluentAssertions;
using Xunit;
using Xunit.Abstractions;


namespace ATAP.Utilities.GraphDataStructures.UnitTests
{
  public class GraphDataStructuresFixture : DiFixture { }
  public partial class GraphDataStructuresUnitTests001 : IClassFixture<GraphDataStructuresFixture>
  {
    protected GraphDataStructuresFixture Fixture { get; }
    protected ITestOutputHelper TestOutput { get; }
    public GraphDataStructuresUnitTests001(ITestOutputHelper testOutput, GraphDataStructuresFixture fixture)
    {
      Fixture = fixture;
      TestOutput = testOutput;
    }
  }
}
