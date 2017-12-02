
using System;
using ATAP.Utilities.Logging.Logging;
// brings in LogLib
using NLog;

namespace ATAP.Utilities.Logging {
    /*
    // this example form https://brutaldev.com/post/logging-setup-in-5-minutes-with-nlog
    public static class Log
    {
    
    public static Logger Instance { get; private set; }
    static Log()
    {
    #if DEBUG
    // Setup the logging view for Sentinel - http://sentinel.codeplex.com
    var sentinalTarget = new NLogViewerTarget()
    {
    Name = "sentinal",
    Address = "udp://127.0.0.1:9999",
    IncludeNLogData = false
    };
    var sentinalRule = new LoggingRule("*", LogLevel.Trace, sentinalTarget);
    LogManager.Configuration.AddTarget("sentinal", sentinalTarget);
    LogManager.Configuration.LoggingRules.Add(sentinalRule);
    
    // Setup the logging view for Harvester - http://harvester.codeplex.com
    var harvesterTarget = new OutputDebugStringTarget()
    {
    Name = "harvester",
    Layout = "${log4jxmlevent:includeNLogData=false}"
    };
    var harvesterRule = new LoggingRule("*", LogLevel.Trace, harvesterTarget);
    LogManager.Configuration.AddTarget("harvester", harvesterTarget);
    LogManager.Configuration.LoggingRules.Add(harvesterRule);
    #endif
    
    LogManager.ReconfigExistingLoggers();
    
    Instance = LogManager.GetCurrentClassLogger();
    }
    
    }
    */
    /// Experiments with LibLog and NLog
#region LibLog and Nlog

        
    public  class LoggingTest {
        internal static ILog iLog;
        static LoggingTest() {
            LogManager.Configuration = LogManager.Configuration.Reload();
            LogManager.ReconfigExistingLoggers();
        }
        public LoggingTest()
        {
            iLog = LogProvider.For<LoggingTest>();
        }
        public static void TestLogging() {
            if(iLog.IsDebugEnabled()) {
                iLog.Debug("hello world");
            }
        }
    }
    public class SharedLogging<T>
    {
        static ILog iLog;
        static SharedLogging()
        {
            LogManager.Configuration = LogManager.Configuration.Reload();
            LogManager.ReconfigExistingLoggers();
        }
        public  SharedLogging()
        {
            iLog = LogProvider.For<T>();
        }
        public static void TestLogging()
        {
            if (iLog.IsDebugEnabled())
            {
                iLog.Debug("hello world");
            }
        }
    }

   
    #endregion
}
