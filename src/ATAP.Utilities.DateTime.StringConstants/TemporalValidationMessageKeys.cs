namespace ATAP.Utilities.DateTime.StringConstants;

/// <summary>
/// Localization keys for the ratified temporal validation failures.
/// </summary>
public static class TemporalValidationMessageKeys
{
  public const string UtcInstantOffsetMustBeZero = "Temporal.UtcInstant.OffsetMustBeZero";
  public const string TemporalDurationMustBeNonNegative = "Temporal.Duration.MustBeNonNegative";
  public const string ValidToUtcMustBeAfterValidFromUtc = "Temporal.ValidityPeriod.ValidToUtcMustBeAfterValidFromUtc";
  public const string PeriodSetMustContainOnlyValidPeriods = "Temporal.ValidityPeriodSet.MustContainOnlyValidPeriods";
  public const string TransitionMemberMustOccurExactlyOnce = "Temporal.Transition.MemberMustOccurExactlyOnce";
  public const string OpenPeriodStateMustPermitTransition = "Temporal.Transition.OpenPeriodStateMustPermitTransition";
  public const string SplitInstantMustBeStrictlyInterior = "Temporal.Transition.SplitInstantMustBeStrictlyInterior";
  public const string MergePeriodsMustAbut = "Temporal.Transition.MergePeriodsMustAbut";
  public const string OpenPeriodCalculationRequiresHorizon = "Temporal.Calculation.OpenPeriodRequiresHorizon";
  public const string JsonPayloadIsInvalidOrLegacy = "Temporal.Json.PayloadIsInvalidOrLegacy";
}
