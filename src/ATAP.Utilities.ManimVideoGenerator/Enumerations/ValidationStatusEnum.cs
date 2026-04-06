namespace ATAP.Utilities.ManimVideoGenerator
{
  /// <summary>Outcome returned by a validation agent.</summary>
  public enum ValidationStatusEnum
  {
    /// <summary>The subject under validation meets all quality criteria.</summary>
    Approved,
    /// <summary>The subject under validation has been rejected; a reason is attached.</summary>
    Rejected,
  }
}
