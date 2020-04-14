
using System;
using System.Collections.Generic;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Logging.Abstractions;

// https://www.nexmo.com/blog/2020/02/10/adaptive-library-logging-with-microsoft-extensions-logging-dr
namespace ATAP.Utilities.Logging {
  public static class LogProvider {
    private static IDictionary<string, ILogger> _loggers = new Dictionary<string, ILogger>();
    private static ILoggerFactory _loggerFactory = new LoggerFactory();

    public static void SetLogFactory(ILoggerFactory factory) {
      _loggerFactory?.Dispose();
      _loggerFactory = factory;
      _loggers.Clear();
    }

    public static ILogger GetLogger(string category) {
      if (!_loggers.ContainsKey(category)) {
        _loggers[category] = _loggerFactory?.CreateLogger(category) ?? NullLogger.Instance;
      }
      return _loggers[category];
    }
  }

}
  //public static class LoggingUtilities
  //  {
  //      // Internal logger for this class
  //      //ToDo figure out how to create an iLog log for a static class
  //      // internal static ILog log = LogProvider.For<LoggingUtilities>();

  //      /// <summary>
  //      /// Gets the assembly logger.
  //      /// </summary>
  //      /// <returns>ILog.</returns>
  //      // static ILog GetAssemblyLogger()
  //      // {
  //          // throw new NotImplementedException();
  //          // /*
  //                      // return LogManager.GetLogger(Assembly.GetExecutingAssembly()
  //                                                           // .GetName()
  //                                                           // .Name);
  //          // */
  //      // }

  //      /// <summary>
  //      /// Gets the namespace logger.
  //      /// </summary>
  //      /// <returns>ILog.</returns>
  //      // [MethodImpl(MethodImplOptions.NoInlining)]
  //      // static ILog GetNamespaceLogger()
  //      // {
  //          // throw new NotImplementedException();
  //          // /*
  //                      // var frame = new StackFrame(1);
  //                      // var callingMethod = frame.GetMethod();
  //                      // return LogManager.GetLogger(callingMethod.DeclaringType.Namespace);
  //          // */
  //      // }

  //      public static string GetFriendlyName(this Type type)
  //      {
  //          if (type.IsGenericType)
  //          {
  //              return $"{type.Name.Split('`')[0]}<{(string.Join(", ", type.GetGenericArguments().Select(GetFriendlyName)))}>";
  //          }
  //          else
  //          {
  //              return type.Name;
  //          }
  //      }

  //      // public static void Reconfigure()
  //      // {
  //          // throw new NotImplementedException();
  //          // ///Need to figure out how to use LibLog for this instead of NLog directly
  //          // //LogManager.Configuration = LogManager.Configuration.Reload();
  //          // //LogManager.ReconfigExistingLoggers();
  //      // }

  //  }
  //  public class LoggingUtilitiesLoggingTest
  //  {
  //      // #region Configure this class to use ATAP.Utilities.Logging
  //      // // Internal class logger for this class
  //      // private static ILog log;
  //      // static LoggingUtilitiesLoggingTest()
  //      // {
  //          // log = LogProvider.For<LoggingUtilitiesLoggingTest>();
  //      // }
  //      // internal static ILog Log { get => log; set => log = value; }
  //      // #endregion Configure this class to use ATAP.Utilities.Logging
  //      // public LoggingUtilitiesLoggingTest()
  //      // {

  //      // }


  //      // public void TestLogging()
  //      // {
  //          // Log.Trace("Sample trace message");
  //          // Log.Debug("Sample debug message");
  //          // Log.Info("Sample informational message");
  //          // Log.Warn("Sample warning message");
  //          // Log.Error("Sample error message");
  //          // Log.Fatal("Sample fatal error message");

  //          // // alternatively you can call the Log() method
  //          // // and pass log level as the parameter.
  //          // Log.InfoFormat("Sample informational message from {0} ", "joe");
  //      // }

  //  }



