using System;
using ATAP.Utilities.DateTime.Interfaces;
using ATAP.Utilities.DateTime.Model;
using FluentAssertions;
using Xunit;

namespace ATAP.Utilities.DateTime.Tests;

[Trait("Category", "Unit")]
public sealed class TemporalValidityPeriodUnitTests
{
  [Fact]
  public void Contains_BoundedPeriod_IncludesExactStartAndExcludesExactEnd()
  {
    // Arrange
    var start = Instant(0);
    var end = Instant(10);
    var period = new TemporalValidityPeriod(start, end);

    // Act
    var containsStart = period.Contains(start);
    var containsInterior = period.Contains(Instant(9));
    var containsEnd = period.Contains(end);

    // Assert
    containsStart.Should().BeTrue();
    containsInterior.Should().BeTrue();
    containsEnd.Should().BeFalse();
  }

  [Fact]
  public void OpenEndedPeriod_ContainsAnyLaterInstantAndHasNoDuration()
  {
    // Arrange
    var start = Instant(0);
    var period = new TemporalValidityPeriod(start, null);

    // Act
    var containsLater = period.Contains(Instant(10_000));

    // Assert
    period.IsOpenEnded.Should().BeTrue();
    period.Duration.Should().BeNull();
    containsLater.Should().BeTrue();
  }

  [Fact]
  public void BoundedPeriod_ComputesDerivedDuration()
  {
    // Arrange
    var period = new TemporalValidityPeriod(Instant(0), Instant(25));

    // Act
    var duration = period.Duration;

    // Assert
    period.IsOpenEnded.Should().BeFalse();
    duration.Should().Be(new TemporalDuration(TimeSpan.FromTicks(25)));
  }

  [Theory]
  [InlineData(0)]
  [InlineData(-1)]
  public void Constructor_EndEqualToOrEarlierThanStart_ThrowsNamingValidToUtc(long endOffsetTicks)
  {
    // Arrange
    var start = Instant(10);
    var end = Instant(10 + endOffsetTicks);

    // Act
    var action = () => new TemporalValidityPeriod(start, end);

    // Assert
    action.Should().Throw<ArgumentOutOfRangeException>()
      .Which.ParamName.Should().Be("validToUtc");
  }

  [Fact]
  public void Equality_SameBoundaries_IsStructural()
  {
    // Arrange
    var left = new TemporalValidityPeriod(Instant(0), Instant(10));
    var right = new TemporalValidityPeriod(Instant(0), Instant(10));
    var different = new TemporalValidityPeriod(Instant(0), Instant(11));

    // Act
    var equal = left == right;

    // Assert
    equal.Should().BeTrue();
    left.Should().Be(right);
    left.GetHashCode().Should().Be(right.GetHashCode());
    left.Should().NotBe(different);
  }

  private static UtcInstant Instant(long offsetTicks) => new(DateTimeOffset.UnixEpoch.AddTicks(offsetTicks));
}
