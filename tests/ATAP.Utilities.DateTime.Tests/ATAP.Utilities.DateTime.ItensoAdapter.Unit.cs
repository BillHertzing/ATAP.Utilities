using System;
using System.Collections.Generic;
using System.Linq;
using ATAP.Utilities.DateTime.Interfaces;
using ATAP.Utilities.DateTime.Model;
using FluentAssertions;
using Microsoft.Extensions.DependencyInjection;
using Xunit;

namespace ATAP.Utilities.DateTime.Tests;

[Trait("Category", "Unit")]
public sealed class ItensoTemporalPeriodCalculatorUnitTests
{
  private readonly ItensoTemporalPeriodCalculator _calculator = new();

  [Fact]
  public void Contains_BoundedPeriod_UsesClosedStartAndOpenEnd()
  {
    var period = Period(0, 10);

    _calculator.Contains(period, Instant(0)).Should().BeTrue();
    _calculator.Contains(period, Instant(9)).Should().BeTrue();
    _calculator.Contains(period, Instant(10)).Should().BeFalse();
  }

  [Fact]
  public void Contains_OpenPeriod_DoesNotInventVendorSentinel()
  {
    var period = Period(10, null);

    _calculator.Contains(period, Instant(9)).Should().BeFalse();
    _calculator.Contains(period, Instant(10)).Should().BeTrue();
    _calculator.Contains(period, Instant(10_000)).Should().BeTrue();
  }

  [Fact]
  public void Overlaps_AbuttingPeriods_ReturnsFalse()
  {
    _calculator.Overlaps(Period(0, 10), Period(10, 20)).Should().BeFalse();
    _calculator.Overlaps(Period(0, 11), Period(10, 20)).Should().BeTrue();
    _calculator.Overlaps(Period(10, null), Period(0, 10)).Should().BeFalse();
    _calculator.Overlaps(Period(9, null), Period(0, 10)).Should().BeTrue();
  }

  [Fact]
  public void GetBoundedIntersection_TwoArgumentOpenInput_Throws()
  {
    var action = () => _calculator.GetBoundedIntersection(Period(0, null), Period(5, 10));

    action.Should().Throw<InvalidOperationException>()
      .WithMessage("*explicit open-end horizon*");
  }

  [Fact]
  public void GetBoundedIntersection_BoundedInputs_ReturnsATAPPeriodOrNull()
  {
    var intersection = _calculator.GetBoundedIntersection(Period(0, 10), Period(5, 20));
    var abutting = _calculator.GetBoundedIntersection(Period(0, 10), Period(10, 20));

    intersection.Should().BeOfType<TemporalValidityPeriod>();
    intersection!.ValidFromUtc.Should().Be(Instant(5));
    intersection.ValidToUtc.Should().Be(Instant(10));
    abutting.Should().BeNull();
  }

  [Fact]
  public void GetBoundedIntersection_HorizonSubstitutesOnlyOpenEnds()
  {
    var openIntersection = _calculator.GetBoundedIntersection(
      Period(5, null),
      Period(0, 100),
      Instant(20));
    var boundedIntersection = _calculator.GetBoundedIntersection(
      Period(5, 15),
      Period(0, 100),
      Instant(20));

    openIntersection!.ValidToUtc.Should().Be(Instant(20));
    boundedIntersection!.ValidToUtc.Should().Be(Instant(15));
  }

  [Fact]
  public void GetBoundedIntersection_HorizonNotAfterEveryOpenStart_Throws()
  {
    var action = () => _calculator.GetBoundedIntersection(
      Period(0, null),
      Period(20, null),
      Instant(20));

    action.Should().Throw<ArgumentOutOfRangeException>()
      .Which.ParamName.Should().Be("openEndHorizonUtc");
  }

  [Fact]
  public void GetInternalGaps_OrderedNonOverlappingPeriods_ReturnsOnlyBoundedInternalGaps()
  {
    IReadOnlyList<IHalfOpenTemporalPeriod> periods = new IHalfOpenTemporalPeriod[]
    {
      Period(0, 10),
      Period(10, 20),
      Period(25, 30),
      Period(40, null),
    };

    var gaps = _calculator.GetInternalGaps(periods);

    gaps.Should().HaveCount(2);
    gaps.Should().AllBeOfType<TemporalValidityPeriod>();
    gaps[0].Should().Be(Period(20, 25));
    gaps[1].Should().Be(Period(30, 40));
  }

  [Fact]
  public void GetInternalGaps_UnorderedOverlappingOrOpenBeforeLast_RejectsCollection()
  {
    Action unordered = () => _calculator.GetInternalGaps(new IHalfOpenTemporalPeriod[]
    {
      Period(10, 20),
      Period(0, 5),
    });
    Action overlapping = () => _calculator.GetInternalGaps(new IHalfOpenTemporalPeriod[]
    {
      Period(0, 10),
      Period(9, 20),
    });
    Action openBeforeLast = () => _calculator.GetInternalGaps(new IHalfOpenTemporalPeriod[]
    {
      Period(0, null),
      Period(10, 20),
    });

    unordered.Should().Throw<ArgumentException>().Which.ParamName.Should().Be("periods");
    overlapping.Should().Throw<ArgumentException>().Which.ParamName.Should().Be("periods");
    openBeforeLast.Should().Throw<ArgumentException>().Which.ParamName.Should().Be("periods");
  }

  [Fact]
  public void PublicSurface_ExposesNoItensoTypes()
  {
    var exposedTypes = typeof(ItensoTemporalPeriodCalculator)
      .GetMethods()
      .Where(method => method.IsPublic && method.DeclaringType == typeof(ItensoTemporalPeriodCalculator))
      .SelectMany(method => method.GetParameters().Select(parameter => parameter.ParameterType)
        .Append(method.ReturnType))
      .Where(type => type.FullName?.Contains("Itenso", StringComparison.Ordinal) == true)
      .ToArray();

    exposedTypes.Should().BeEmpty();
  }

  [Fact]
  public void AddATAPUtilitiesDateTime_RegistersExactSingletonAndReturnsSameCollection()
  {
    var services = new ServiceCollection();

    var returned = global::ATAP.Utilities.DateTime.ServiceCollectionExtensions
      .AddATAPUtilitiesDateTime(services);

    returned.Should().BeSameAs(services);
    services.Should().ContainSingle(descriptor =>
      descriptor.ServiceType == typeof(ITemporalPeriodCalculator)
      && descriptor.ImplementationType == typeof(ItensoTemporalPeriodCalculator)
      && descriptor.Lifetime == ServiceLifetime.Singleton);
  }

  [Fact]
  public void AddATAPUtilitiesDateTime_NullCollection_ThrowsNamingServices()
  {
    IServiceCollection? services = null;

    var action = () => global::ATAP.Utilities.DateTime.ServiceCollectionExtensions
      .AddATAPUtilitiesDateTime(services!);

    action.Should().Throw<ArgumentNullException>()
      .Which.ParamName.Should().Be("services");
  }

  private static TemporalValidityPeriod Period(long startTicks, long? endTicks)
    => new(Instant(startTicks), endTicks is null ? null : Instant(endTicks.Value));

  private static UtcInstant Instant(long offsetTicks)
    => new(DateTimeOffset.UnixEpoch.AddTicks(offsetTicks));
}
