using System;
using System.Text.Json.Serialization;

namespace ATAP.Utilities.DateTime.Interfaces;

/// <summary>
/// Represents a UTC instant without silently normalizing an offset-bearing input.
/// </summary>
[JsonConverter(typeof(UtcInstantJsonConverter))]
public readonly record struct UtcInstant : IComparable<UtcInstant>
{
  /// <summary>
  /// Initializes a new instance of the <see cref="UtcInstant"/> struct.
  /// </summary>
  /// <param name="value">The UTC instant to retain.</param>
  /// <exception cref="ArgumentException">Thrown when <paramref name="value"/> has a nonzero offset.</exception>
  public UtcInstant(DateTimeOffset value)
  {
    if (value.Offset != TimeSpan.Zero)
    {
      throw new ArgumentException("The value offset must be UTC.", nameof(value));
    }

    Value = value;
  }

  /// <summary>
  /// Gets the exact UTC value, including its original tick precision.
  /// </summary>
  public DateTimeOffset Value { get; }

  /// <inheritdoc />
  public int CompareTo(UtcInstant other) => Value.CompareTo(other.Value);
}
