using System;
using System.Text.Json.Serialization;
using ATAP.Utilities.DateTime.Interfaces;

namespace ATAP.Utilities.DateTime.Model;

/// <summary>
/// Represents an immutable UTC validity interval with an inclusive start and an optional exclusive end.
/// </summary>
[JsonConverter(typeof(TemporalValidityPeriodJsonConverter))]
public sealed record TemporalValidityPeriod : ITemporalValidityPeriod
{
  /// <summary>
  /// Initializes a new instance of the <see cref="TemporalValidityPeriod"/> class.
  /// </summary>
  /// <param name="validFromUtc">The inclusive UTC start instant.</param>
  /// <param name="validToUtc">The exclusive UTC end instant, or <see langword="null"/> for an open-ended period.</param>
  /// <exception cref="ArgumentOutOfRangeException">Thrown when <paramref name="validToUtc"/> is not later than <paramref name="validFromUtc"/>.</exception>
  public TemporalValidityPeriod(UtcInstant validFromUtc, UtcInstant? validToUtc)
  {
    if (validToUtc is { } end && end.CompareTo(validFromUtc) <= 0)
    {
      throw new ArgumentOutOfRangeException(nameof(validToUtc), validToUtc, "The end instant must be later than the start instant.");
    }

    ValidFromUtc = validFromUtc;
    ValidToUtc = validToUtc;
  }

  /// <inheritdoc />
  public UtcInstant ValidFromUtc { get; }

  /// <inheritdoc />
  public UtcInstant? ValidToUtc { get; }

  /// <inheritdoc />
  public bool IsOpenEnded => ValidToUtc is null;

  /// <inheritdoc />
  public TemporalDuration? Duration => ValidToUtc is { } end
    ? new TemporalDuration(end.Value - ValidFromUtc.Value)
    : null;

  /// <inheritdoc />
  public bool Contains(UtcInstant instant) => instant.CompareTo(ValidFromUtc) >= 0
    && (ValidToUtc is null || instant.CompareTo(ValidToUtc.Value) < 0);
}
