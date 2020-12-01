using ATAP.Utilities.ComputerInventory.Software;
using Medallion.Shell;
using System;

namespace ATAP.Utilities.ComputerInventory.ProcessInfo
{

  public static partial class Extensions
  {

    public static int Start(this IComputerProcesses computerProcesses, IComputerSoftwareProgram computerSoftwareProgram, params object[] arguments) //Command command, 
    {
      ComputerProcess computerProcess = new ComputerProcess(computerSoftwareProgram, arguments); //command, 
      int pid = computerProcess.Start();
      computerProcesses.ComputerProcessDictionary.Add(pid, computerProcess);
      return pid;
    }

    public static void Kill(this ComputerProcesses computerProcesses, int pid)
    {
      computerProcesses.ComputerProcessDictionary[pid].Kill();
    }

    public static int Start(this ComputerProcess computerProcess)
    {
      computerProcess.Command = Command.Run(computerProcess.ComputerSoftwareProgram.ComputerSoftwareProgramSignil.ProcessPath, computerProcess.Arguments, options: o => o.DisposeOnExit(false));
      return computerProcess.Command.ProcessId;
    }
    public static void Kill(this ComputerProcess computerProcess)
    {
      computerProcess.Command.Process.Kill();
    }
    public static void Kill(this IComputerProcess computerProcess)
    {
      computerProcess.Command.Process.Kill();
    }
    public static bool CloseMainWindow(this ComputerProcess computerProcess)
    {
      return computerProcess.Command.Process.CloseMainWindow();
    }
    public static void Close(this ComputerProcess computerProcess)
    {
      computerProcess.Command.Process.Close();
    }

  }
}
