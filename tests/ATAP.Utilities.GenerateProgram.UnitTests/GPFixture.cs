


using ATAP.Utilities.Testing;
using FluentAssertions;
using Xunit;
using Xunit.Abstractions;


namespace GenerateProgram.UnitTests
{
  public partial class GPFixture : Fixture {
    public string Result;
  }

  public partial class GPTests : IClassFixture<GPFixture>
  {
    protected GPFixture Fixture { get; }
    protected ITestOutputHelper TestOutput { get; }
    public GPTests(ITestOutputHelper testOutput, GPFixture fixture)
    {
      Fixture = fixture;
      TestOutput = testOutput;
    }
  }
}
