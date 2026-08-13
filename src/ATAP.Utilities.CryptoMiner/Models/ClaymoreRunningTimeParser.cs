using System;
using System.Globalization;
using ATAP.Utilities.DateTime.Interfaces;

namespace ATAP.Utilities.CryptoMiner.Models;

internal static class ClaymoreRunningTimeParser
{
  internal static TemporalDuration ParseMinutes(string value)
  {
    if (!long.TryParse(value, NumberStyles.None, CultureInfo.InvariantCulture, out var runningMinutes) || runningMinutes < 0)
    {
      throw new ArgumentException("Claymore running time must be a non-negative whole number of invariant-culture minutes.", nameof(value));
    }

    try
    {
      return new TemporalDuration(TimeSpan.FromMinutes(runningMinutes));
    }
    catch (OverflowException)
    {
      throw new ArgumentOutOfRangeException(nameof(value), value, "Claymore running time exceeds the supported duration range.");
    }
  }
}
