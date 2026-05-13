
using ATAP.Utilities.Testing;
using FluentAssertions;
using Xunit;
using Xunit.Abstractions;


namespace ATAP.Utilities.Serializer.UnitTests
{
  public class Fixture : SerializationFixture { }
  public partial class UnitTests001 : IClassFixture<Fixture >
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
