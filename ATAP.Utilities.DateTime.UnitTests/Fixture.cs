


using ATAP.Utilities.Testing;
using FluentAssertions;
using Xunit;
using Xunit.Abstractions;


namespace ATAP.Utilities.DateTime.UnitTests
{
  public class DateTimeFixture : Fixture { }
  public partial class DateTimeUnitTests001 : IClassFixture<DateTimeFixture>
  {
    protected DateTimeFixture Fixture { get; }
    protected ITestOutputHelper TestOutput { get; }
    public DateTimeUnitTests001(ITestOutputHelper testOutput, DateTimeFixture fixture)
    {
      Fixture = fixture;
      TestOutput = testOutput;
    }
  }
}
