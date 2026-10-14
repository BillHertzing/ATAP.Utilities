using Xunit;

namespace ATAP.Utilities.Logging.Tests {
  [Trait("Category", "Unit")]
  public class LoggingUnitTests001 {
    [Fact]
    public void GetLogger_SameCategory_ReturnsCachedLogger() {
      var first = LogProvider.GetLogger("ATAP.Utilities.Logging.Tests.Cached");
      var second = LogProvider.GetLogger("ATAP.Utilities.Logging.Tests.Cached");

      Assert.Same(first, second);
    }

    [Fact]
    public void GetLogger_DifferentCategories_ReturnsDifferentLoggers() {
      var first = LogProvider.GetLogger("ATAP.Utilities.Logging.Tests.First");
      var second = LogProvider.GetLogger("ATAP.Utilities.Logging.Tests.Second");

      Assert.NotSame(first, second);
    }
  }
}
