using System;
using System.Globalization;
using System.Reflection;
using ATAP.Utilities.DateTime.Interfaces;
using ATAP.Utilities.CryptoMiner.Models;
using FluentAssertions;
using Xunit;

namespace ATAP.Utilities.CryptoMiner.Tests;

public sealed class ClaymoreTemporalDurationUnitTests
{
  [Fact]
  public void RunningTimeUsesInvariantWholeMinutes()
  {
    // Arrange
    using var culture = new CultureScope("fr-FR");

    // Act
    TemporalDuration result = Parse("15");

    // Assert
    result.Should().Be(new TemporalDuration(TimeSpan.FromMinutes(15)));
  }

  [Theory]
  [InlineData("1,5")]
  [InlineData("1.5")]
  [InlineData("-1")]
  [InlineData("not-a-duration")]
  public void RunningTimeRejectsMalformedOrCultureSensitiveValues(string value)
  {
    // Arrange
    using var culture = new CultureScope("fr-FR");

    // Act
    Action act = () => Parse(value);

    // Assert
    act.Should().Throw<ArgumentException>();
  }

  private static TemporalDuration Parse(string value)
  {
    Type parserType = typeof(ClaymoreMinerStatusDetails).Assembly.GetType(
        "ATAP.Utilities.CryptoMiner.Models.ClaymoreRunningTimeParser",
        throwOnError: true) ?? throw new InvalidOperationException("The Claymore running-time parser was not found.");
    MethodInfo method = parserType.GetMethod(
        "ParseMinutes",
        BindingFlags.NonPublic | BindingFlags.Static) ??
        throw new InvalidOperationException("The Claymore running-time parser was not found.");

    try
    {
      return (TemporalDuration)(method.Invoke(null, new object[] { value }) ??
          throw new InvalidOperationException("The parser returned null."));
    }
    catch (TargetInvocationException exception) when (exception.InnerException is not null)
    {
      throw exception.InnerException;
    }
  }

  private sealed class CultureScope : IDisposable
  {
    private readonly CultureInfo originalCulture = CultureInfo.CurrentCulture;
    private readonly CultureInfo originalUICulture = CultureInfo.CurrentUICulture;

    public CultureScope(string cultureName)
    {
      CultureInfo culture = CultureInfo.GetCultureInfo(cultureName);
      CultureInfo.CurrentCulture = culture;
      CultureInfo.CurrentUICulture = culture;
    }

    public void Dispose()
    {
      CultureInfo.CurrentCulture = originalCulture;
      CultureInfo.CurrentUICulture = originalUICulture;
    }
  }
}
