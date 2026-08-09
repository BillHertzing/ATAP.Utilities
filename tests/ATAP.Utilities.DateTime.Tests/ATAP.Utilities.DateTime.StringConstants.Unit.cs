using System;
using System.Collections.Generic;
using System.Linq;
using System.Reflection;
using ATAP.Utilities.DateTime.StringConstants;
using FluentAssertions;
using Xunit;

namespace ATAP.Utilities.DateTime.Tests;

public class DateTimeStringConstantsUnitTests
{
  [Fact]
  public void TemporalJsonPropertyNames_HaveRatifiedExactValues()
  {
    var values = GetPublicConstantValues(typeof(TemporalJsonPropertyNames));

    values.Should().Equal("id", "additionalIds", "validityPeriods", "validFromUtc", "validToUtc", "ticks");
  }

  [Fact]
  public void TemporalPersistenceNames_HaveRatifiedExactValues()
  {
    var values = GetPublicConstantValues(typeof(TemporalPersistenceNames));

    values.Should().Equal("PhiloteValidityPeriod", "ValidFromUtc", "ValidToUtc", "PreviousValidToUtc");
  }

  [Fact]
  public void TemporalValidationMessageKeys_ContainOnlyRatifiedErrorKeys()
  {
    var values = GetPublicConstantValues(typeof(TemporalValidationMessageKeys));

    values.Should().Equal(
      "Temporal.UtcInstant.OffsetMustBeZero",
      "Temporal.Duration.MustBeNonNegative",
      "Temporal.ValidityPeriod.ValidToUtcMustBeAfterValidFromUtc",
      "Temporal.ValidityPeriodSet.MustContainOnlyValidPeriods",
      "Temporal.Transition.MemberMustOccurExactlyOnce",
      "Temporal.Transition.OpenPeriodStateMustPermitTransition",
      "Temporal.Transition.SplitInstantMustBeStrictlyInterior",
      "Temporal.Transition.MergePeriodsMustAbut",
      "Temporal.Calculation.OpenPeriodRequiresHorizon",
      "Temporal.Json.PayloadIsInvalidOrLegacy");
  }

  [Theory]
  [InlineData(typeof(TemporalJsonPropertyNames))]
  [InlineData(typeof(TemporalPersistenceNames))]
  [InlineData(typeof(TemporalValidationMessageKeys))]
  public void TemporalConstantValues_AreUniqueWithinTheirContractBoundary(Type constantContainer)
  {
    var values = GetPublicConstantValues(constantContainer);

    values.Should().OnlyHaveUniqueItems();
  }

  [Theory]
  [InlineData(typeof(TemporalJsonPropertyNames))]
  [InlineData(typeof(TemporalPersistenceNames))]
  [InlineData(typeof(TemporalValidationMessageKeys))]
  public void TemporalConstantValues_ContainNoSqlOrBehaviorOrFormatFragments(Type constantContainer)
  {
    var prohibitedFragments = new[] { "SELECT", "INSERT", "UPDATE", "DELETE", "CREATE", "ALTER", "DROP", "{0}", "yyyy" };

    foreach (var value in GetPublicConstantValues(constantContainer))
    {
      foreach (var prohibitedFragment in prohibitedFragments)
      {
        value.Should().NotContain(prohibitedFragment, because: $"{constantContainer.Name} is a names-only contract");
      }
    }
  }

  private static IReadOnlyList<string> GetPublicConstantValues(Type constantContainer) =>
    constantContainer
      .GetFields(BindingFlags.Public | BindingFlags.Static)
      .Where(field => field.IsLiteral && !field.IsInitOnly && field.FieldType == typeof(string))
      .OrderBy(field => field.MetadataToken)
      .Select(field => (string)field.GetRawConstantValue()!)
      .ToArray();
}
