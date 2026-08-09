using System;
using System.Collections.Generic;
using ATAP.Utilities.DateTime.Interfaces;
using ATAP.Utilities.DateTime.Model;
using ATAP.Utilities.StronglyTypedId;

namespace ATAP.Utilities.Philote.Tests;

public sealed record TestGuidId : GuidStronglyTypedId
{
  public TestGuidId()
  {
  }

  public TestGuidId(Guid value)
    : base(value)
  {
  }
}

public static class PhiloteTestData
{
  public static readonly UtcInstant First = At(0);
  public static readonly UtcInstant Second = At(1);
  public static readonly UtcInstant Third = At(2);
  public static readonly UtcInstant Fourth = At(3);

  public static IEnumerable<object[]> ValidPeriodCollections()
  {
    yield return new object[] { Array.Empty<TemporalValidityPeriod>() };
    yield return new object[] { new[] { new TemporalValidityPeriod(First, Second) } };
    yield return new object[] { new[] { new TemporalValidityPeriod(First, null) } };
    yield return new object[]
    {
      new[]
      {
        new TemporalValidityPeriod(First, Second),
        new TemporalValidityPeriod(Second, Third)
      }
    };
    yield return new object[]
    {
      new[]
      {
        new TemporalValidityPeriod(First, Second),
        new TemporalValidityPeriod(Third, Fourth)
      }
    };
  }

  public static UtcInstant At(int day) =>
    new(new DateTimeOffset(2026, 8, 8 + day, 0, 0, 0, TimeSpan.Zero));
}
