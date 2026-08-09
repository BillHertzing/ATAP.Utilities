using System;
using System.Collections.Generic;
using ATAP.Utilities.DateTime.Interfaces;
using Itenso.TimePeriod;

namespace ATAP.Utilities.DateTime.Model;

/// <summary>
/// Adapts ATAP-owned half-open temporal calculations to TimePeriodLibrary.NET.
/// </summary>
public sealed class ItensoTemporalPeriodCalculator : ITemporalPeriodCalculator
{
  /// <inheritdoc />
  public bool Contains(IHalfOpenTemporalPeriod period, UtcInstant instant)
  {
    ValidatePeriod(period, nameof(period));

    if (period.ValidToUtc is null)
    {
      return instant.CompareTo(period.ValidFromUtc) >= 0;
    }

    return ExecuteVendor(
      () => MapBounded(period, nameof(period)).HasInside(ToVendorDateTime(instant)),
      "The bounded containment calculation failed.");
  }

  /// <inheritdoc />
  public bool Overlaps(IHalfOpenTemporalPeriod left, IHalfOpenTemporalPeriod right)
  {
    ValidatePeriod(left, nameof(left));
    ValidatePeriod(right, nameof(right));

    if (left.ValidToUtc is not null && right.ValidToUtc is not null)
    {
      return ExecuteVendor(
        () => MapBounded(left, nameof(left)).IntersectsWith(MapBounded(right, nameof(right))),
        "The bounded overlap calculation failed.");
    }

    return (left.ValidToUtc is null || right.ValidFromUtc.CompareTo(left.ValidToUtc.Value) < 0)
      && (right.ValidToUtc is null || left.ValidFromUtc.CompareTo(right.ValidToUtc.Value) < 0);
  }

  /// <inheritdoc />
  public IHalfOpenTemporalPeriod? GetBoundedIntersection(
    IHalfOpenTemporalPeriod left,
    IHalfOpenTemporalPeriod right)
  {
    ValidatePeriod(left, nameof(left));
    ValidatePeriod(right, nameof(right));

    if (left.ValidToUtc is null || right.ValidToUtc is null)
    {
      throw new InvalidOperationException(
        "Open-ended periods require the overload with an explicit open-end horizon.");
    }

    return GetBoundedIntersectionCore(
      left.ValidFromUtc,
      left.ValidToUtc.Value,
      right.ValidFromUtc,
      right.ValidToUtc.Value);
  }

  /// <inheritdoc />
  public IHalfOpenTemporalPeriod? GetBoundedIntersection(
    IHalfOpenTemporalPeriod left,
    IHalfOpenTemporalPeriod right,
    UtcInstant openEndHorizonUtc)
  {
    ValidatePeriod(left, nameof(left));
    ValidatePeriod(right, nameof(right));

    var leftEnd = ResolveEnd(left, openEndHorizonUtc);
    var rightEnd = ResolveEnd(right, openEndHorizonUtc);

    return GetBoundedIntersectionCore(
      left.ValidFromUtc,
      leftEnd,
      right.ValidFromUtc,
      rightEnd);
  }

  /// <inheritdoc />
  public IReadOnlyList<IHalfOpenTemporalPeriod> GetInternalGaps(
    IReadOnlyList<IHalfOpenTemporalPeriod> periods)
  {
    ArgumentNullException.ThrowIfNull(periods);

    var gaps = new List<IHalfOpenTemporalPeriod>();
    IHalfOpenTemporalPeriod? previous = null;

    for (var index = 0; index < periods.Count; index++)
    {
      var current = periods[index];
      if (current is null)
      {
        throw new ArgumentException("The period collection cannot contain null elements.", nameof(periods));
      }

      ValidatePeriod(current, nameof(periods));

      if (previous is not null)
      {
        if (current.ValidFromUtc.CompareTo(previous.ValidFromUtc) < 0)
        {
          throw new ArgumentException("The period collection must be ordered by start instant.", nameof(periods));
        }

        if (previous.ValidToUtc is null
          || current.ValidFromUtc.CompareTo(previous.ValidToUtc.Value) < 0)
        {
          throw new ArgumentException("The period collection cannot contain overlapping periods.", nameof(periods));
        }

        if (current.ValidFromUtc.CompareTo(previous.ValidToUtc.Value) > 0)
        {
          gaps.Add(new TemporalValidityPeriod(previous.ValidToUtc.Value, current.ValidFromUtc));
        }
      }

      previous = current;
    }

    return gaps.AsReadOnly();
  }

  private static IHalfOpenTemporalPeriod? GetBoundedIntersectionCore(
    UtcInstant leftStart,
    UtcInstant leftEnd,
    UtcInstant rightStart,
    UtcInstant rightEnd)
  {
    var intersects = ExecuteVendor(
      () => MapBounded(leftStart, leftEnd).IntersectsWith(MapBounded(rightStart, rightEnd)),
      "The bounded intersection calculation failed.");

    if (!intersects)
    {
      return null;
    }

    var intersectionStart = leftStart.CompareTo(rightStart) >= 0 ? leftStart : rightStart;
    var intersectionEnd = leftEnd.CompareTo(rightEnd) <= 0 ? leftEnd : rightEnd;
    return new TemporalValidityPeriod(intersectionStart, intersectionEnd);
  }

  private static UtcInstant ResolveEnd(
    IHalfOpenTemporalPeriod period,
    UtcInstant openEndHorizonUtc)
  {
    if (period.ValidToUtc is { } boundedEnd)
    {
      return boundedEnd;
    }

    if (openEndHorizonUtc.CompareTo(period.ValidFromUtc) <= 0)
    {
      throw new ArgumentOutOfRangeException(
        nameof(openEndHorizonUtc),
        openEndHorizonUtc,
        "The open-end horizon must be later than every open period start.");
    }

    return openEndHorizonUtc;
  }

  private static void ValidatePeriod(IHalfOpenTemporalPeriod? period, string parameterName)
  {
    if (period is null)
    {
      throw new ArgumentNullException(parameterName);
    }

    if (period.ValidToUtc is { } end && end.CompareTo(period.ValidFromUtc) <= 0)
    {
      throw new ArgumentException("The period end must be later than its start.", parameterName);
    }
  }

  private static TimeInterval MapBounded(IHalfOpenTemporalPeriod period, string parameterName)
  {
    if (period.ValidToUtc is not { } end)
    {
      throw new InvalidOperationException(
        $"The {parameterName} period must be bounded before vendor mapping.");
    }

    return MapBounded(period.ValidFromUtc, end);
  }

  private static TimeInterval MapBounded(UtcInstant start, UtcInstant end)
    => new(
      ToVendorDateTime(start),
      ToVendorDateTime(end),
      IntervalEdge.Closed,
      IntervalEdge.Open,
      isIntervalEnabled: true,
      isReadOnly: true);

  private static global::System.DateTime ToVendorDateTime(UtcInstant instant)
    => instant.Value.UtcDateTime;

  private static T ExecuteVendor<T>(Func<T> operation, string message)
  {
    try
    {
      return operation();
    }
    catch (Exception exception) when (exception is not OutOfMemoryException)
    {
      throw new InvalidOperationException(message, exception);
    }
  }
}
