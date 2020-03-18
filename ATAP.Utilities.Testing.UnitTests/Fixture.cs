


using ATAP.Utilities.Testing;
using FluentAssertions;
using Xunit;
using Xunit.Abstractions;


namespace ATAP.Utilities.Testing.UnitTests
{
  public class TestingFixture : Fixture { }
  public partial class TestingUnitTests001 : IClassFixture<TestingFixture>
  {
    protected TestingFixture Fixture { get; }
    protected ITestOutputHelper TestOutput { get; }
    public TestingUnitTests001(ITestOutputHelper testOutput, TestingFixture fixture)
    {
      Fixture = fixture;
      TestOutput = testOutput;
    }
  }
}
