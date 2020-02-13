using System;
using Xunit;
using ATAP.Utilities.DateTime;
using FluentAssertions;

namespace ATAP.Utilities.DateTime.UnitTests
{
  public class Fixture
  {
    public Fixture()
    {

    }
  }
  public class DateTimeUnitTests001 : IClassFixture<Fixture>
  {
    protected Fixture fixture;
    public DateTimeUnitTests001(Fixture fixture)
    {
      this.fixture = fixture;
    }

    [Theory]

    [InlineData(2000, 1, 1, 100000, 9467100)]
    // Test ToUnixTime
    public void ConvertToUnixTime(int inYear, int inMonth, int inDay, int inUnixUOM, int inExpectedUnixTime)
    {
      long result = ATAP.Utilities.DateTime.Utilities.ToUnixTime(new System.DateTime(inYear, inMonth, inDay), inUnixUOM);
      result.Should().Be(inExpectedUnixTime);
    }
  }

}
