using System.ComponentModel;

namespace ATAP.Utilities.ComputerInventory.Enumerations
{
  // ToDo: Move into a separate assembly dedicated to extending GenericHost to make it easy to run as a Console or windows service or Linux Daemon
  public enum RuntimePlatformLifetime {
    [Description("WindowsConsoleApp")]
    WindowsConsoleApp,
    [Description("WindowsService")]
    WindowsService,
    [Description("LinuxConsoleApp")]
    LinuxConsoleApp,
    [Description("LinuxDaemon")]
    LinuxDaemon,
    [Description("FreeBSDConsoleApp")]
    FreeBSDConsoleApp,
    [Description("FreeBSDDaemon")]
    FreeBSDDaemon,
    [Description("OSXConsoleApp")]
    OSXConsoleApp,
    [Description("OSXDaemon")]
    OSXDaemon
  }
}

