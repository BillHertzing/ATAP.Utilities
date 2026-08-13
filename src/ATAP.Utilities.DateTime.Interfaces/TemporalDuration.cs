using System;
using System.Text.Json.Serialization;

namespace ATAP.Utilities.DateTime.Interfaces;

/// <summary>
/// Represents a non-negative elapsed duration.
/// </summary>
[JsonConverter(typeof(TemporalDurationJsonConverter))]
public readonly record struct TemporalDuration : IComparable<TemporalDuration>
{
  /// <summary>
  /// Initializes a new instance of the <see cref="TemporalDuration"/> struct.
  /// </summary>
  /// <param name="timeSpan">The non-negative duration.</param>
  /// <exception cref="ArgumentOutOfRangeException">Thrown when <paramref name="timeSpan"/> is negative.</exception>
  public TemporalDuration(TimeSpan timeSpan)
  {
    if (timeSpan < TimeSpan.Zero)
    {
      throw new ArgumentOutOfRangeException(nameof(timeSpan), timeSpan, "The duration must not be negative.");
    }

    TimeSpan = timeSpan;
  }

  /// <summary>
  /// Gets the represented duration.
  /// </summary>
  public TimeSpan TimeSpan { get; }

  /// <summary>
  /// Gets the represented duration as ticks.
  /// </summary>
  public long Ticks => TimeSpan.Ticks;

  /// <inheritdoc />
  public int CompareTo(TemporalDuration other) => TimeSpan.CompareTo(other.TimeSpan);
}
