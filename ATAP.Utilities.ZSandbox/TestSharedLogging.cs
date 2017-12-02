using System;
using System.Collections.Generic;
using System.Text;
using ATAP.Utilities.Logging;
using ATAP.Utilities.Logging.Logging;

namespace ATAP.Utilities.ZSandbox
{
    public class TestSharedLogging
    {
        internal static ILog log;

        public TestSharedLogging()
        {
            log = LogProvider.For<TestSharedLogging>();
        }


        // Register this class as a logger consumer
        // get the current configuration, add this logger, update and reload

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
           log.InfoFormat("Sample informational message from {0} ","joe");

        }

    }
}
