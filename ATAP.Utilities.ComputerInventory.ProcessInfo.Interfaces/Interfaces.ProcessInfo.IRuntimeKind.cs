using ATAP.Utilities.ComputerInventory.Enumerations;

namespace ATAP.Utilities.ComputerInventory.Interfaces.ProcessInfo
{
  public interface IRuntimeKind
  {
    bool IsConsoleApplication { get; }
    bool IsFreeBSD { get; }
    bool IsLinux { get; }
    bool IsOSX { get; }
    bool IsWindows { get; }
    RuntimePlatformLifetime Kind { get; }
  }

}
