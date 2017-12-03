
using System.Reflection;
using Xunit;
using ATAP.Utilities.Logging.Logging;


namespace ATAP.Utilities.Logging.UnitTests
{
 
    public class Fixture
    {
        public Fixture()
        {
        }
    }


    public class TestSharedLogging
    {
        #region Configure this class to use ATAP.Utilities.Logging
        internal static ILog log { get; set; }

        static TestSharedLogging()
        {
            log = LogProvider.For<TestSharedLogging>();
        }
        #endregion Configure this class to use ATAP.Utilities.Logging

        public TestSharedLogging()
        {
            log = LogProvider.GetLogger(this.GetType().Namespace + "." + this.GetType().GetFriendlyName());
        }
        public void TestLogging()
        {
            log.Trace("Sample trace message");
            log.Debug("Sample debug message");
            log.Info("Sample informational message");
            log.Warn("Sample warning message");
            log.Error("Sample error message");
            log.Fatal("Sample fatal error message");

            // alternatively you can call the Log() method
            // and pass log level as the parameter.
            log.InfoFormat("Sample informational message from {0} ", "joe");
        }

    }

    public class LoggingUnitTests001 : IClassFixture<Fixture>
{
        Fixture _fixture;
        public LoggingUnitTests001(Fixture fixture)
        {
            _fixture = fixture;
        }
        [Fact]
        void LoggingUtilitiesBuiltInLoggingTest()
        {
            var x = new LoggingUtilitiesLoggingTest();
            x.TestLogging();
            // ToDo - rewrite this to reconfigure the config for this class to a target where teh test can verify, then change the config back
            Assert.Equal(1, 1);
        }
        [Fact]
        void SharedLoggingTest()
        {
            var x = new TestSharedLogging();
            x.TestLogging();
            // ToDo - rewrite this to reconfigure the config for this class to a target where teh test can verify, then change the config back
            Assert.Equal(1, 1);
        }
    }
}
