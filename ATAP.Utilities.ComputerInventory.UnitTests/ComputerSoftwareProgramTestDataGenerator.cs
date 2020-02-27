using System.Collections.Generic;
using System.Collections;
using ATAP.Utilities.ComputerInventory.Configuration.Software;
using System;
using ATAP.Utilities.ConcurrentObservableCollections;

namespace ATAP.Utilities.ComputerInventory.Configuration.UnitTests
{

  //ToDo add validation tests to ensure illegal values are not allowed.  This applies to all XxTestDataGenerator classes
  public class ComputerSoftwareProgramTestData
  {
    public ComputerSoftwareProgram ComputerSoftwareProgram;
    public string SerializedComputerSoftwareProgram;

    public ComputerSoftwareProgramTestData()
    {
    }

    public ComputerSoftwareProgramTestData(ComputerSoftwareProgram computerSoftwareProgram, string serializedComputerSoftwareProgram)
    {
      ComputerSoftwareProgram = computerSoftwareProgram ?? throw new ArgumentNullException(nameof(computerSoftwareProgram));
      SerializedComputerSoftwareProgram = serializedComputerSoftwareProgram ?? throw new ArgumentNullException(nameof(serializedComputerSoftwareProgram));
    }
  }

  public class ComputerSoftwareProgramTestDataGenerator : IEnumerable<object[]>
  {
    public static IEnumerable<object[]> ComputerSoftwareProgramTestData()
    {
      yield return new ComputerSoftwareProgramTestData[] { new ComputerSoftwareProgramTestData { ComputerSoftwareProgram = new ComputerSoftwareProgram(
              "powershell",
              @"C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe",
              "v5",
              ".",
              false,
              new ConcurrentObservableDictionary<string, string>(),
              ".",
              true,
              true,
              false,
              "",
              false,
              "*.log",
               "."
        ), SerializedComputerSoftwareProgram = "{\"Maker\":0}" } };
      yield return new ComputerSoftwareProgramTestData[] { new ComputerSoftwareProgramTestData { ComputerSoftwareProgram = new ComputerSoftwareProgram(
               "EthDCRMiner",
              @"C:\",
              "v1",
              ".",
              false,
              new ConcurrentObservableDictionary<string, string>(),
              ".",
              true,
              true,
              false,
              "",
              false,
              "*.log",
               "."

        ), SerializedComputerSoftwareProgram = "{\"Maker\":1}" } };
      // ToDo: Add the Miner program with the status log files
      // ToDo: Add the old Dos/Windows CMD processor
      // ToDo: Add Linux shells

    }
    public IEnumerator<object[]> GetEnumerator() { return ComputerSoftwareProgramTestData().GetEnumerator(); }
    IEnumerator IEnumerable.GetEnumerator() { return GetEnumerator(); }
  }
}
