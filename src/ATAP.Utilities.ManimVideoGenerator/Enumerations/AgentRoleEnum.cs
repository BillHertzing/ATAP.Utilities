namespace ATAP.Utilities.ManimVideoGenerator
{
  /// <summary>Identifies the role of a Semantic Kernel agent in the two-stage pipeline.</summary>
  public enum AgentRoleEnum
  {
    /// <summary>Validates whether the user prompt is feasible as a Manim animation.</summary>
    QueryValidator,
    /// <summary>Expands a short prompt into a detailed scene-by-scene description.</summary>
    DescriptionExpander,
    /// <summary>Iteratively refines a scene description when validation fails.</summary>
    DescriptionRefiner,
    /// <summary>Re-checks a refined description for quality and completeness.</summary>
    DescriptionValidator,
    /// <summary>Translates an accepted description into a Manim Python script string.</summary>
    CodeGenerator,
    /// <summary>Validates that the generated code faithfully implements the description.</summary>
    CodeValidator,
  }
}
