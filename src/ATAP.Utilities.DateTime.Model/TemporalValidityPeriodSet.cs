using System;
using System.Collections;
using System.Collections.Generic;
using System.Linq;
using System.Text.Json.Serialization;
using ATAP.Utilities.DateTime.Interfaces;

namespace ATAP.Utilities.DateTime.Model;

/// <summary>
/// Represents an immutable, ordered, non-overlapping set of temporal-validity periods.
/// </summary>
[JsonConverter(typeof(TemporalValidityPeriodSetJsonConverter))]
public sealed class TemporalValidityPeriodSet :
  IReadOnlyList<TemporalValidityPeriod>,
  IEquatable<TemporalValidityPeriodSet>
{
  private readonly TemporalValidityPeriod[] periods;

  /// <summary>
  /// Gets the reusable empty temporal-validity period set.
  /// </summary>
  public static TemporalValidityPeriodSet Empty { get; } = new();

  /// <summary>
  /// Initializes a new instance of the <see cref="TemporalValidityPeriodSet"/> class.
  /// </summary>
  /// <param name="periods">The periods to copy, sort, and validate, or <see langword="null"/> for an empty set.</param>
  /// <exception cref="ArgumentException">
  /// Thrown when an element is null, starts are duplicated, periods overlap, or an open-ended period is not the sole last period.
  /// </exception>
  public TemporalValidityPeriodSet(IEnumerable<ITemporalValidityPeriod>? periods = null)
  {
    var source = periods is null ? Array.Empty<ITemporalValidityPeriod>() : periods.ToArray();

    if (source.Any(static period => period is null))
    {
      throw new ArgumentException("The collection must not contain a null period.", nameof(periods));
    }

    var snapshot = source
      .Select(static period => Materialize(period))
      .ToArray();

    Array.Sort(snapshot, static (left, right) => left.ValidFromUtc.CompareTo(right.ValidFromUtc));
    ValidateSnapshot(snapshot, nameof(periods));
    this.periods = snapshot;
  }

  /// <inheritdoc />
  public int Count => periods.Length;

  /// <inheritdoc />
  public TemporalValidityPeriod this[int index] => periods[index];

  /// <summary>
  /// Determines whether the specified instant belongs to a validity period in this set.
  /// </summary>
  /// <param name="instant">The instant to test.</param>
  /// <returns><see langword="true"/> when one period contains the instant; otherwise, <see langword="false"/>.</returns>
  public bool IsValidAt(UtcInstant instant)
  {
    foreach (var period in periods)
    {
      if (period.Contains(instant))
      {
        return true;
      }
    }

    return false;
  }

  /// <summary>
  /// Returns a new set with an open-ended period activated at the specified instant.
  /// </summary>
  /// <param name="validFromUtc">The inclusive start of the new open-ended period.</param>
  /// <returns>A new validated set.</returns>
  /// <exception cref="InvalidOperationException">Thrown when this set already contains an open-ended period.</exception>
  public TemporalValidityPeriodSet Activate(UtcInstant validFromUtc)
  {
    if (periods.Length > 0 && periods[^1].IsOpenEnded)
    {
      throw new InvalidOperationException("An open-ended validity period already exists.");
    }

    return new TemporalValidityPeriodSet(
      periods.Append(new TemporalValidityPeriod(validFromUtc, null)));
  }

  /// <summary>
  /// Returns a new set with its current open-ended period closed at the specified instant.
  /// </summary>
  /// <param name="validToUtc">The exclusive end for the current open-ended period.</param>
  /// <returns>A new validated set.</returns>
  /// <exception cref="InvalidOperationException">Thrown when this set has no open-ended period.</exception>
  public TemporalValidityPeriodSet Deactivate(UtcInstant validToUtc)
  {
    if (periods.Length == 0 || !periods[^1].IsOpenEnded)
    {
      throw new InvalidOperationException("No open-ended validity period exists.");
    }

    var replacement = new TemporalValidityPeriod(periods[^1].ValidFromUtc, validToUtc);
    var result = (TemporalValidityPeriod[])periods.Clone();
    result[^1] = replacement;
    return new TemporalValidityPeriodSet(result);
  }

  /// <summary>
  /// Returns a new set in which exactly one structurally equal member is replaced.
  /// </summary>
  /// <param name="current">The existing member to replace.</param>
  /// <param name="replacement">The replacement period.</param>
  /// <returns>A new validated set.</returns>
  public TemporalValidityPeriodSet Replace(
    ITemporalValidityPeriod current,
    ITemporalValidityPeriod replacement)
  {
    ArgumentNullException.ThrowIfNull(current);
    ArgumentNullException.ThrowIfNull(replacement);

    var currentIndex = FindSingleIndex(current, nameof(current));
    var result = (TemporalValidityPeriod[])periods.Clone();
    result[currentIndex] = Materialize(replacement);
    return new TemporalValidityPeriodSet(result);
  }

  /// <summary>
  /// Returns a new set in which one member is split at a strict interior instant.
  /// </summary>
  /// <param name="current">The existing member to split.</param>
  /// <param name="splitAtUtc">The strict interior split instant.</param>
  /// <returns>A new validated set.</returns>
  public TemporalValidityPeriodSet Split(
    ITemporalValidityPeriod current,
    UtcInstant splitAtUtc)
  {
    ArgumentNullException.ThrowIfNull(current);

    var currentIndex = FindSingleIndex(current, nameof(current));
    if (splitAtUtc.CompareTo(current.ValidFromUtc) <= 0
      || current.ValidToUtc is { } currentEnd && splitAtUtc.CompareTo(currentEnd) >= 0)
    {
      throw new ArgumentOutOfRangeException(
        nameof(splitAtUtc),
        splitAtUtc,
        "The split instant must be strictly inside the current period.");
    }

    var result = periods.ToList();
    result.RemoveAt(currentIndex);
    result.Insert(currentIndex, new TemporalValidityPeriod(current.ValidFromUtc, splitAtUtc));
    result.Insert(currentIndex + 1, new TemporalValidityPeriod(splitAtUtc, current.ValidToUtc));
    return new TemporalValidityPeriodSet(result);
  }

  /// <summary>
  /// Returns a new set in which two consecutive, exactly abutting members are merged.
  /// </summary>
  /// <param name="earlier">The earlier existing member.</param>
  /// <param name="later">The immediately following existing member.</param>
  /// <returns>A new validated set.</returns>
  public TemporalValidityPeriodSet Merge(
    ITemporalValidityPeriod earlier,
    ITemporalValidityPeriod later)
  {
    ArgumentNullException.ThrowIfNull(earlier);
    ArgumentNullException.ThrowIfNull(later);

    var earlierIndex = FindSingleIndex(earlier, nameof(earlier));
    var laterIndex = FindSingleIndex(later, nameof(later));
    if (laterIndex != earlierIndex + 1
      || earlier.ValidToUtc is not { } earlierEnd
      || !earlierEnd.Equals(later.ValidFromUtc))
    {
      throw new ArgumentException(
        "The later period must immediately follow and exactly abut the earlier period.",
        nameof(later));
    }

    var result = periods.ToList();
    result[earlierIndex] = new TemporalValidityPeriod(earlier.ValidFromUtc, later.ValidToUtc);
    result.RemoveAt(laterIndex);
    return new TemporalValidityPeriodSet(result);
  }

  /// <inheritdoc />
  public bool Equals(TemporalValidityPeriodSet? other)
  {
    if (ReferenceEquals(this, other))
    {
      return true;
    }

    if (other is null || Count != other.Count)
    {
      return false;
    }

    for (var index = 0; index < periods.Length; index++)
    {
      if (periods[index] != other.periods[index])
      {
        return false;
      }
    }

    return true;
  }

  /// <inheritdoc />
  public override bool Equals(object? obj) => obj is TemporalValidityPeriodSet other && Equals(other);

  /// <inheritdoc />
  public override int GetHashCode()
  {
    var hash = new HashCode();
    foreach (var period in periods)
    {
      hash.Add(period);
    }

    return hash.ToHashCode();
  }

  /// <summary>
  /// Determines whether two sets contain the same canonical sequence of periods.
  /// </summary>
  public static bool operator ==(TemporalValidityPeriodSet? left, TemporalValidityPeriodSet? right) =>
    ReferenceEquals(left, right) || left is not null && left.Equals(right);

  /// <summary>
  /// Determines whether two sets do not contain the same canonical sequence of periods.
  /// </summary>
  public static bool operator !=(TemporalValidityPeriodSet? left, TemporalValidityPeriodSet? right) => !(left == right);

  /// <inheritdoc />
  public IEnumerator<TemporalValidityPeriod> GetEnumerator() =>
    ((IEnumerable<TemporalValidityPeriod>)periods).GetEnumerator();

  /// <inheritdoc />
  IEnumerator IEnumerable.GetEnumerator() => GetEnumerator();

  private static void ValidateSnapshot(
    IReadOnlyList<TemporalValidityPeriod> snapshot,
    string parameterName)
  {
    for (var index = 1; index < snapshot.Count; index++)
    {
      var previous = snapshot[index - 1];
      var current = snapshot[index];

      if (current.ValidFromUtc.Equals(previous.ValidFromUtc))
      {
        throw new ArgumentException("Validity-period starts must be unique.", parameterName);
      }

      if (previous.IsOpenEnded)
      {
        throw new ArgumentException("No validity period may follow an open-ended period.", parameterName);
      }

      if (previous.ValidToUtc is { } previousEnd
        && previousEnd.CompareTo(current.ValidFromUtc) > 0)
      {
        throw new ArgumentException("Validity periods must not overlap.", parameterName);
      }
    }
  }

  private int FindSingleIndex(ITemporalValidityPeriod member, string parameterName)
  {
    var foundIndex = -1;
    var matchCount = 0;

    for (var index = 0; index < periods.Length; index++)
    {
      if (HasSameBoundaries(periods[index], member))
      {
        foundIndex = index;
        matchCount++;
      }
    }

    if (matchCount != 1)
    {
      throw new ArgumentException("The transition member must occur exactly once.", parameterName);
    }

    return foundIndex;
  }

  private static TemporalValidityPeriod Materialize(ITemporalValidityPeriod period) =>
    period is TemporalValidityPeriod concrete
      ? concrete
      : new TemporalValidityPeriod(period.ValidFromUtc, period.ValidToUtc);

  private static bool HasSameBoundaries(
    ITemporalValidityPeriod left,
    ITemporalValidityPeriod right) =>
    left.ValidFromUtc.Equals(right.ValidFromUtc)
    && Nullable.Equals(left.ValidToUtc, right.ValidToUtc);
}
