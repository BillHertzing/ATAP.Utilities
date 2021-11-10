
using ATAP.Utilities.Testing;
using FluentAssertions;
using Xunit;
using Xunit.Abstractions;


namespace ATAP.Utilities.Serializer.UnitTests
{
  public class Fixture : ATAP.Utilities.Testing.ConfigurableFixture { }
  public partial class SerializerUnitTests001 : IClassFixture<Fixture>
  {
    protected Fixture Fixture { get; }
    protected ITestOutputHelper TestOutput { get; }
    public SerializerUnitTests001(ITestOutputHelper testOutput, Fixture fixture)
    {
      Fixture = fixture;
      TestOutput = testOutput;
    }
  }
}
