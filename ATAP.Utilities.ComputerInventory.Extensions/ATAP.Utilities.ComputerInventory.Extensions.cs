using System;
using System.Collections.Generic;
using ATAP.Utilities.ComputerInventory.Interfaces.ProcessInfo;
using ATAP.Utilities.ComputerInventory.Interfaces.Software;
using ATAP.Utilities.ComputerInventory.Configuration;
using ATAP.Utilities.ComputerInventory.Configuration.Hardware;
using ATAP.Utilities.ComputerInventory.Configuration.ProcessInfo;
using Medallion.Shell;
using ATAP.Utilities.ComputerInventory.Models.Hardware;
using ATAP.Utilities.ComputerInventory.Interfaces.Hardware;

namespace ATAP.Utilities.ComputerInventory.Extensions
{
  public static partial class Extensions
  {
    public static ComputerInventory InventoryThisComputer(this ComputerInventory computerInventory)
    {
      throw new NotImplementedException();
    }

    //ToDo: Implement writing a ComputerInventory object to a set of Configuration Settings
    public static Dictionary<string, string> ToConfigurationSettings(this ComputerInventory computerInventory)
    {
      throw new NotImplementedException();
    }

    //ToDo: Implement creating a ComputerInventory object from a set of Configuration Settings
    public static ComputerInventory FromConfigurationSettings(Dictionary<string, string> configurationSettings)
    {
      throw new NotImplementedException();
    }

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
      computerProcess.Command = Command.Run(computerProcess.ComputerSoftwareProgram.ProcessPath, computerProcess.Arguments, options: o => o.DisposeOnExit(false));
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

    public static void OpenComputer(this IComputerHardware computerHardware)
    {
#if NETFUL
    computerHardware.Computer = new Computer
      {
        MainboardEnabled = computerHardware.isMainboardEnabled,
        CPUEnabled = computerHardware.isCPUsEnabled,
        FanControllerEnabled = computerHardware.isFanControllerEnabled,
        GPUEnabled = computerHardware.isVideoCardsEnabled
  };
  // ToDo: Get teh HardwareMonitorLib to work, right now, it throws an exception it can't find system.management dll
  //computer.Open();
#else
#endif
    }
  }

  /*
  Abstract:
  ComputerInventory
  Moment or span?
  Motherboard
  CPU
  Memory
  Disks
  PowerSupply
  USBPorts
  VideoCards
  Software
  Drivers
  Mining Programs (includes both name and version)
  AceAgent

  Concrete:
  "FactoryReset", AKA AllDummy (moment, 1/1/1980)
  "CurrentActual" (span, from start of program (or last change) to now())
  "Profile or hypothetical" (span or moment, can include planned time spans)

  ConcurrentObservableDictionary<TimePeriod, ComputerInventory> changeHistoryComputerInventory (each has non-overlapping periods, should be in the aggregate a contiguous span).

  *****
  Current actual Inventory
  is there a changeHistoryComputerInventory in the configuration settings, or a ChangeHistoryComputerInventoryFile (or DB)?
  yes - create and load a change history object, make currentActual = latest history
  is there a currentComputerInventory in the configuration settings, or a CurrentComputerInventoryFile (or DB)?
  yes - compare currentActual
  if there is nothing, currentComputerInventory = FactoryReset, and changeHistory = currentComputerInventory
  create foundComputerInventory ( run the take inventory method)
  if foundComputerInventory == currentComputerInventory, done, else currentComputerInventory = foundComputerInventory and add currentComputerInventory to changeHistoryComputerInventory
  at this point, the currentComputerInventory object is up to date

  * */
}
