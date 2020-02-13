using ATAP.Utilities.Logging.Logging;
using Xunit;

namespace ATAP.Utilities.Logging.UnitTests {

  public class Fixture
  {
    public Fixture()
    {
    }
  }


    public class LoggingUnitTests001 : IClassFixture<Fixture> {
        Fixture fixture;

        public LoggingUnitTests001(Fixture fixture) {
      fixture = fixture;
        }


    [Fact]
    void ValidateFatalLogLevel() {
      // ToDo - rewrite this to validate logging, without knowing what the logging configuration is

      //var log = LogProvider.For<ValidateFatalLogLevel>();
      //log.Fatal("Sample fatal error message");
      //log.Trace("Sample trace message");
      //log.Debug("Sample debug message");
      //log.Info("Sample informational message");
      //log.Warn("Sample warning message");
      //log.Error("Sample error message");

      Assert.Equal(1, 1);
    }
    }
}
