using System.Collections.Generic;

namespace ATAP.Utilities.DateTime.Interfaces;

/// <summary>
/// Defines ATAP-owned calculations over half-open temporal periods.
/// </summary>
public interface ITemporalPeriodCalculator
{
  /// <summary>
  /// Determines whether a period contains an instant.
  /// </summary>
  /// <param name="period">The period to inspect.</param>
  /// <param name="instant">The UTC instant to test.</param>
  /// <returns><see langword="true"/> when the period contains the instant; otherwise, <see langword="false"/>.</returns>
  bool Contains(IHalfOpenTemporalPeriod period, UtcInstant instant);

  /// <summary>
  /// Determines whether two periods overlap.
  /// </summary>
  /// <param name="left">The first period.</param>
  /// <param name="right">The second period.</param>
  /// <returns><see langword="true"/> when the periods overlap; otherwise, <see langword="false"/>.</returns>
  bool Overlaps(IHalfOpenTemporalPeriod left, IHalfOpenTemporalPeriod right);

  /// <summary>
  /// Gets the bounded intersection of two bounded periods.
  /// </summary>
  /// <param name="left">The first period.</param>
  /// <param name="right">The second period.</param>
  /// <returns>The bounded intersection, or <see langword="null"/> when there is no intersection.</returns>
  IHalfOpenTemporalPeriod? GetBoundedIntersection(
    IHalfOpenTemporalPeriod left,
    IHalfOpenTemporalPeriod right);

  /// <summary>
  /// Gets the bounded intersection of two periods, applying a horizon to any open end.
  /// </summary>
  /// <param name="left">The first period.</param>
  /// <param name="right">The second period.</param>
  /// <param name="openEndHorizonUtc">The UTC horizon used only for an open end.</param>
  /// <returns>The bounded intersection, or <see langword="null"/> when there is no intersection.</returns>
  IHalfOpenTemporalPeriod? GetBoundedIntersection(
    IHalfOpenTemporalPeriod left,
    IHalfOpenTemporalPeriod right,
    UtcInstant openEndHorizonUtc);

  /// <summary>
  /// Gets bounded gaps between consecutive ordered, non-overlapping periods.
  /// </summary>
  /// <param name="periods">The ordered periods to inspect.</param>
  /// <returns>The bounded internal gaps.</returns>
  IReadOnlyList<IHalfOpenTemporalPeriod> GetInternalGaps(
    IReadOnlyList<IHalfOpenTemporalPeriod> periods);
}
