


using ATAP.Utilities.Testing;
using FluentAssertions;
using Xunit;
using Xunit.Abstractions;


namespace ATAP.Utilities.Philote.UnitTests
{
  public class PhiloteFixture : Fixture { }
  public partial class PhiloteUnitTests001 : IClassFixture<PhiloteFixture>
  {
    protected PhiloteFixture Fixture { get; }
    protected ITestOutputHelper TestOutput { get; }
    public PhiloteUnitTests001(ITestOutputHelper testOutput, PhiloteFixture fixture)
    {
      Fixture = fixture;
      TestOutput = testOutput;
    }
  }
}
