using System;
using ATAP.Utilities.CryptoCoin.Models;
using ATAP.Utilities.DateTime.Interfaces;
using FluentAssertions;
using Xunit;

namespace ATAP.Utilities.CryptoCoin.Tests;

public sealed class CryptoCoinTemporalDurationUnitTests
{
  [Fact]
  public void AverageShareSafePreservesDurationTicks()
  {
    // Arrange
    var data = CreateData(
        averageBlockCreationSpan: TimeSpan.FromMinutes(10),
        blockRewardPerBlock: 2,
        minerHashRatePerSecond: 10,
        networkHashRatePerSecond: 100);
    var duration = new TemporalDuration(TimeSpan.FromMinutes(20));

    // Act
    double result = CryptoCoinNetworkInfo.AverageShareOfBlockRewardPerSpanSafe(data, duration);

    // Assert
    result.Should().BeApproximately(0.4, 0.0000001);
  }

  [Fact]
  public void AverageShareSafeRejectsZeroDurationDivisor()
  {
    // Arrange
    var data = CreateData(TimeSpan.Zero, 2, 10, 100);

    // Act
    Action act = () => CryptoCoinNetworkInfo.AverageShareOfBlockRewardPerSpanSafe(
        data,
        new TemporalDuration(TimeSpan.FromMinutes(1)));

    // Assert
    act.Should().Throw<DivideByZeroException>();
  }

  [Fact]
  public void AverageShareSafeRejectsOverflow()
  {
    // Arrange
    var data = CreateData(TimeSpan.FromTicks(1), double.MaxValue, double.MaxValue, double.Epsilon);

    // Act
    Action act = () => CryptoCoinNetworkInfo.AverageShareOfBlockRewardPerSpanSafe(
        data,
        new TemporalDuration(TimeSpan.MaxValue));

    // Assert
    act.Should().Throw<OverflowException>();
  }

  private static AverageShareOfBlockRewardDT CreateData(
      TimeSpan averageBlockCreationSpan,
      double blockRewardPerBlock,
      double minerHashRatePerSecond,
      double networkHashRatePerSecond) =>
      new(
          new TemporalDuration(averageBlockCreationSpan),
          blockRewardPerBlock,
          new TemporalDuration(TimeSpan.FromMinutes(1)),
          new HashRate(minerHashRatePerSecond, TimeSpan.FromSeconds(1)),
          new HashRate(networkHashRatePerSecond, TimeSpan.FromSeconds(1)));
}
