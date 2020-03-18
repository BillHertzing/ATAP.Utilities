using System.ComponentModel;

namespace ATAP.Utilities.ComputerInventory.Enumerations
{
  // ToDo: Move into a separate assembly dedicated to extending GenericHost to make it easy to run as a Console or windows service or Linux Daemon
  public enum RuntimePlatformLifetime {
    [Description("WindowsConsoleApp")]
    WindowsConsoleApp = 0,
    [Description("WindowsService")]
    WindowsService = 1,
    [Description("LinuxConsoleApp")]
    LinuxConsoleApp = 2,
    [Description("LinuxDaemon")]
    LinuxDaemon = 3,
    [Description("FreeBSDConsoleApp")]
    FreeBSDConsoleApp = 4,
    [Description("FreeBSDDaemon")]
    FreeBSDDaemon = 5,
    [Description("OSXConsoleApp")]
    OSXConsoleApp = 6,
    [Description("OSXDaemon")]
    OSXDaemon = 7
  }
}

