
using ATAP.Utilities.Testing;
using ATAP.Utilities.Testing.Serialization;
using FluentAssertions;
using Xunit;
using Xunit.Abstractions;

namespace ATAP.Utilities.Testing.Fixture.Serialization.Shim.Newtonsoft.UnitTests
{
  public class Fixture : SerializationFixtureNewtonsoft  { }
  public partial class UnitTests001 : IClassFixture<Fixture>
  {
    protected Fixture Fixture { get; }
    protected ITestOutputHelper TestOutput { get; }
    public UnitTests001(ITestOutputHelper testOutput, Fixture fixture)
    {
      Fixture = fixture;
      TestOutput = testOutput;
    }
  }
}
