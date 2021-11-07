using FluentAssertions;
using Xunit;
using Xunit.Abstractions;

using ATAP.Utilities.Testing;
using ATAP.Services.Timers;

namespace ATAP.Services.Timers.UnitTests
{
  public class Fixture : DiFixtureNInject { }
  public partial class TimersUnitTests001 : IClassFixture<Fixture>
  {
    protected Fixture Fixture { get; }
    protected ITestOutputHelper TestOutput { get; }
    public TimersUnitTests001(ITestOutputHelper testOutput, Fixture fixture)
    {
      Fixture = fixture;
      TestOutput = testOutput;
    }
  }
}
