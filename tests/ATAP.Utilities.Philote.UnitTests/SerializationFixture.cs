using ATAP.Utilities.Testing;
using FluentAssertions;
using Xunit;
using Xunit.Abstractions;

namespace ATAP.Utilities.Philote.UnitTests
{
  public class SerializationFixture : Fixture { }
  public partial class SerializationUnitTests001 : IClassFixture<SerializationFixture>
  {
    protected SerializationFixture Fixture { get; }
    protected ITestOutputHelper TestOutput { get; }
    public SerializationUnitTests001(ITestOutputHelper testOutput, SerializationFixture fixture)
    {
      Fixture = fixture;
      TestOutput = testOutput;
    }
  }
}
