using NLog;
using NLog.Config;
using NLog.Targets;
using System.Reflection;
using Xunit;

namespace ATAP.Utilities.Logging.UnitTests
{
 
    public class Fixture
    {
        private string hello;

        public Fixture()
        {
            Hello = "Hello";
        }

        public string Hello { get => hello; set => hello = value; }
    }
public class LoggingUnitTests001 : IClassFixture<Fixture>
{
        Fixture _fixture;
        private static Logger logger ;
        public LoggingUnitTests001(Fixture fixture)
        {
            _fixture = fixture;
            logger = LogManager.GetCurrentClassLogger();
        }

        [Fact]
         void LogOnceEveryLevel()
        {
            logger.Trace("Sample trace message");
            logger.Debug("Sample debug message");
            logger.Info("Sample informational message");
            logger.Warn("Sample warning message");
            logger.Error("Sample error message");
            logger.Fatal("Sample fatal error message");

            // alternatively you can call the Log() method
            // and pass log level as the parameter.
            logger.Log(LogLevel.Info, "Sample informational message");
            Assert.Equal(1, 1);

        }
    }
}
