namespace ATAP.Utilities.DateTime.Interfaces;

/// <summary>
/// Represents an immutable UTC validity interval with inclusive start and exclusive end boundaries.
/// </summary>
public interface IHalfOpenTemporalPeriod
{
  /// <summary>
  /// Gets the inclusive UTC start instant of the period.
  /// </summary>
  UtcInstant ValidFromUtc { get; }

  /// <summary>
  /// Gets the exclusive UTC end instant of the period, or <see langword="null"/> when the period is open ended.
  /// </summary>
  UtcInstant? ValidToUtc { get; }

  /// <summary>
  /// Gets a value indicating whether this period has no known end.
  /// </summary>
  bool IsOpenEnded { get; }

  /// <summary>
  /// Gets the bounded duration, or <see langword="null"/> when the period is open ended.
  /// </summary>
  TemporalDuration? Duration { get; }

  /// <summary>
  /// Determines whether the specified UTC instant is within this half-open period.
  /// </summary>
  /// <param name="instant">The UTC instant to test.</param>
  /// <returns><see langword="true"/> when <paramref name="instant"/> is within the period; otherwise, <see langword="false"/>.</returns>
  bool Contains(UtcInstant instant);
}
