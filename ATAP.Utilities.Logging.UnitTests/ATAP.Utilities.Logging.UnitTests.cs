
using System.Reflection;
using Xunit;
using ATAP.Utilities.Logging;


namespace ATAP.Utilities.Logging.UnitTests
{
 
    public class Fixture
    {
        public Fixture()
        {
        }
    }
public class LoggingUnitTests001 : IClassFixture<Fixture>
{
        Fixture _fixture;
        public LoggingUnitTests001(Fixture fixture)
        {
            _fixture = fixture;
        }
        /*
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
        */
        [Fact]
        void LogTest()
        {
            LoggingTest t = new LoggingTest();
            LoggingTest.TestLogging();
            Assert.Equal(1, 1);

        }
    }
}
