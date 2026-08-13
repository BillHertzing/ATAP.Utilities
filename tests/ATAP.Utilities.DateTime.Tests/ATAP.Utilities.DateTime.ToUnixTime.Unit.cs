using System;
using ATAP.Utilities.DateTime;
using FluentAssertions;
using Xunit;

namespace ATAP.Utilities.DateTime.Tests
{
  [Trait("Category", "Unit")]
  public partial class DateTimeUnitTests001 : IClassFixture<Fixture>
  {
    [Fact]
    public void ToUnixTime_UtcUnixEpoch_ReturnsZero()
    {
      // Arrange
      var value = System.DateTime.UnixEpoch;

      // Act
      var result = value.ToUnixTime(1000);

      // Assert
      result.Should().Be(0);
    }

    [Theory]
    [InlineData(1, 1234567L)]
    [InlineData(1000, 1234L)]
    [InlineData(60000, 20L)]
    public void ToUnixTime_UtcValue_UsesPositiveUnitDivisor(int uom, long expected)
    {
      // Arrange
      var value = System.DateTime.UnixEpoch.AddMilliseconds(1234567);

      // Act
      var result = value.ToUnixTime(uom);

      // Assert
      result.Should().Be(expected);
    }

    [Fact]
    public void ToUnixTime_LocalUnixEpoch_ReturnsZero()
    {
      // Arrange
      var value = System.DateTime.UnixEpoch.ToLocalTime();

      // Act
      var result = value.ToUnixTime(1000);

      // Assert
      result.Should().Be(0);
    }

    [Fact]
    public void ToUnixTime_UtcWholeSecondBeforeEpoch_ReturnsNegativeSecond()
    {
      // Arrange
      var value = System.DateTime.UnixEpoch.AddSeconds(-1);

      // Act
      var result = value.ToUnixTime(1000);

      // Assert
      result.Should().Be(-1);
    }

    [Theory]
    [InlineData(0)]
    [InlineData(-1)]
    public void ToUnixTime_NonPositiveUnitDivisor_ThrowsArgumentOutOfRangeException(int uom)
    {
      // Arrange
      var value = System.DateTime.UnixEpoch;

      // Act
      var action = () => value.ToUnixTime(uom);

      // Assert
      action.Should().Throw<ArgumentOutOfRangeException>()
        .Which.ParamName.Should().Be("uom");
    }
  }
}
