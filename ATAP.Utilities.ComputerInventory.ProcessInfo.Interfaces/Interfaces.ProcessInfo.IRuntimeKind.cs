
namespace ATAP.Utilities.ComputerInventory.ProcessInfo
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
