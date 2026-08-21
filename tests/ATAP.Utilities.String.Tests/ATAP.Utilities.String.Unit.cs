using Xunit;

namespace ATAP.Utilities.String.Tests {
  [Trait("Category", "Unit")]
  public class StringUnitTests001 {
    [Fact]
    public void ReplaceFirst_ReplacesOnlyFirstOccurrence() {
      var result = "alpha beta alpha".ReplaceFirst("alpha", "omega");

      Assert.Equal("omega beta alpha", result);
    }

    [Fact]
    public void ReplaceFirst_MissingSearchText_ReturnsOriginalValue() {
      const string original = "alpha beta";

      var result = original.ReplaceFirst("gamma", "omega");

      Assert.Same(original, result);
    }
  }
}
