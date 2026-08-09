using System;
using ATAP.Utilities.DateTime.Interfaces;
using FluentAssertions;
using Xunit;

namespace ATAP.Utilities.DateTime.Tests;

[Trait("Category", "Unit")]
public sealed class UtcInstantUnitTests
{
  [Fact]
  public void Constructor_UtcValue_PreservesExactValueAndTicks()
  {
    // Arrange
    var value = new DateTimeOffset(2026, 8, 8, 12, 34, 56, TimeSpan.Zero).AddTicks(1_234_567);

    // Act
    var result = new UtcInstant(value);

    // Assert
    result.Value.Should().Be(value);
    result.Value.Ticks.Should().Be(value.Ticks);
  }

  [Fact]
  public void Constructor_NonzeroOffset_ThrowsArgumentExceptionNamingValue()
  {
    // Arrange
    var value = new DateTimeOffset(2026, 8, 8, 12, 34, 56, TimeSpan.FromHours(1));

    // Act
    var action = () => new UtcInstant(value);

    // Assert
    action.Should().Throw<ArgumentException>()
      .Which.ParamName.Should().Be("value");
  }

  [Fact]
  public void Default_ValidUtcMinimum()
  {
    // Arrange
    var result = default(UtcInstant);

    // Act
    var value = result.Value;

    // Assert
    value.Should().Be(DateTimeOffset.MinValue);
    value.Offset.Should().Be(TimeSpan.Zero);
  }

  [Fact]
  public void CompareToAndEquality_DifferentTicks_ReflectChronologicalOrder()
  {
    // Arrange
    var earlier = new UtcInstant(DateTimeOffset.UnixEpoch);
    var later = new UtcInstant(DateTimeOffset.UnixEpoch.AddTicks(1));

    // Act
    var comparison = earlier.CompareTo(later);

    // Assert
    comparison.Should().BeNegative();
    earlier.Should().NotBe(later);
    earlier.Should().Be(new UtcInstant(DateTimeOffset.UnixEpoch));
  }
}
