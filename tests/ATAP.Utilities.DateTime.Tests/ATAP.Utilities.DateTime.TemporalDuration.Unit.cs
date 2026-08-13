using System;
using ATAP.Utilities.DateTime.Interfaces;
using FluentAssertions;
using Xunit;

namespace ATAP.Utilities.DateTime.Tests;

[Trait("Category", "Unit")]
public sealed class TemporalDurationUnitTests
{
  [Fact]
  public void Constructor_NegativeDuration_ThrowsArgumentOutOfRangeExceptionNamingTimeSpan()
  {
    // Arrange
    var timeSpan = TimeSpan.FromTicks(-1);

    // Act
    var action = () => new TemporalDuration(timeSpan);

    // Assert
    action.Should().Throw<ArgumentOutOfRangeException>()
      .Which.ParamName.Should().Be("timeSpan");
  }

  [Fact]
  public void Constructor_ZeroDuration_PreservesZeroTimeSpanAndTicks()
  {
    // Arrange
    var timeSpan = TimeSpan.Zero;

    // Act
    var result = new TemporalDuration(timeSpan);

    // Assert
    result.TimeSpan.Should().Be(timeSpan);
    result.Ticks.Should().Be(0);
  }

  [Fact]
  public void Constructor_PositiveDuration_PreservesTicks()
  {
    // Arrange
    var timeSpan = TimeSpan.FromTicks(1_234_567);

    // Act
    var result = new TemporalDuration(timeSpan);

    // Assert
    result.TimeSpan.Should().Be(timeSpan);
    result.Ticks.Should().Be(timeSpan.Ticks);
  }

  [Fact]
  public void CompareToAndEquality_DifferentTicks_ReflectDurationOrder()
  {
    // Arrange
    var shorter = new TemporalDuration(TimeSpan.Zero);
    var longer = new TemporalDuration(TimeSpan.FromTicks(1));

    // Act
    var comparison = shorter.CompareTo(longer);

    // Assert
    comparison.Should().BeNegative();
    shorter.Should().NotBe(longer);
    shorter.Should().Be(new TemporalDuration(TimeSpan.Zero));
  }
}
