


using ATAP.Utilities.Testing;
using FluentAssertions;
using Xunit;
using Xunit.Abstractions;


namespace ATAP.Utilities.Serializer.UnitTests
{
  public class SerializerFixture : Fixture { }
  public partial class SerializerUnitTests001 : IClassFixture<SerializerFixture>
  {
    protected SerializerFixture Fixture { get; }
    protected ITestOutputHelper TestOutput { get; }
    public SerializerUnitTests001(ITestOutputHelper testOutput, SerializerFixture fixture)
    {
      Fixture = fixture;
      TestOutput = testOutput;
    }
  }
}
