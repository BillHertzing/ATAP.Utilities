using System.Collections.Generic;
using System.Collections;
using System;
using ATAP.Utilities.ComputerInventory.Software;
using ATAP.Utilities.Testing;

namespace ATAP.Utilities.ComputerInventory.Software.UnitTests
{

  //ToDo add validation tests to ensure illegal values are not allowed.  This applies to all XxTestDataGenerator classes
  public class ComputerSoftwareProgramTestData : TestData<ComputerSoftwareProgram>
  {

    public ComputerSoftwareProgramTestData(ComputerSoftwareProgram objTestData, string serializedTestData) : base(objTestData, serializedTestData)
    {
    }
  }

  public class ComputerSoftwareProgramTestDataGenerator : IEnumerable<object[]>
  {

    public static IEnumerable<object[]> TestData()
    {
      yield return new ComputerSoftwareProgramTestData[] {
        new ComputerSoftwareProgramTestData(
          new ComputerSoftwareProgram(DefaultConfiguration.Production["Generic"],
          new Philote.Philote<IComputerSoftwareProgram>()),
        "{\"ComputerSoftwareProgramSignil\":{\"ProcessName\":\"Generic\",\"ProcessPath\":\".\",\"ProcessStartPath\":\".\",\"Version\":\"0.0.0\",\"HasSTDOut\":true,\"HasERROut\":true,\"HasLogFiles\":true,\"LogFileFolder\":\".\",\"LogFileFnPattern\":\".log\",\"HasAPI\":false,\"APIDiscoveryURL\":null,\"HasConfigurationSettings\":false,\"ConfigFilePath\":null},\"Philote\":{\"ID\":\"658370e5-153a-48da-aee7-d9983fbbbbe8\",\"AdditionalIDs\":{},\"TimeBlocks\":[]}}" ) };
      yield return new ComputerSoftwareProgramTestData[] {
        new ComputerSoftwareProgramTestData(
          new ComputerSoftwareProgram(DefaultConfiguration.Production["PowerShell"],
          new Philote.Philote<IComputerSoftwareProgram>()),
        "{\"ComputerSoftwareProgramSignil\":{\"ProcessName\":\"powershell\",\"ProcessPath\":\"C:\\\\Windows\\\\System32\\\\WindowsPowerShell\\\\v1.0\\\\powershell.exe\",\"ProcessStartPath\":\".\",\"Version\":\"v5\",\"HasSTDOut\":true,\"HasERROut\":true,\"HasLogFiles\":true,\"LogFileFolder\":\".\",\"LogFileFnPattern\":\".log\",\"HasAPI\":false,\"APIDiscoveryURL\":null,\"HasConfigurationSettings\":false,\"ConfigFilePath\":null},\"Philote\":{\"ID\":\"d95633fb-042e-4901-825b-124dce4f6698\",\"AdditionalIDs\":{},\"TimeBlocks\":[]}}" ) };
      yield return new ComputerSoftwareProgramTestData[] {
        new ComputerSoftwareProgramTestData(
          new ComputerSoftwareProgram(DefaultConfiguration.Production["dotnet"],
          new Philote.Philote<IComputerSoftwareProgram>()),
        "{\"ComputerSoftwareProgramSignil\":{\"ProcessName\":\"dotnet\",\"ProcessPath\":\"C:\\\\Windows\\\\dotnet.exe\",\"ProcessStartPath\":\".\",\"Version\":\"v16\",\"HasSTDOut\":true,\"HasERROut\":true,\"HasLogFiles\":true,\"LogFileFolder\":\".\",\"LogFileFnPattern\":\".log\",\"HasAPI\":false,\"APIDiscoveryURL\":null,\"HasConfigurationSettings\":false,\"ConfigFilePath\":null},\"Philote\":{\"ID\":\"cbc87719-69ce-4ebf-933b-94a208450a34\",\"AdditionalIDs\":{},\"TimeBlocks\":[]}}" ) };
      yield return new ComputerSoftwareProgramTestData[] {
        new ComputerSoftwareProgramTestData(
          new ComputerSoftwareProgram(DefaultConfiguration.Production["EthDCRMiner"],
          new Philote.Philote<IComputerSoftwareProgram>()),
        "{\"ComputerSoftwareProgramSignil\":{\"ProcessName\":\"EthDCRMiner\",\"ProcessPath\":\"C:\\\\\",\"ProcessStartPath\":\".\",\"Version\":\"v1\",\"HasSTDOut\":false,\"HasERROut\":false,\"HasLogFiles\":false,\"LogFileFolder\":\".\",\"LogFileFnPattern\":\".log\",\"HasAPI\":false,\"APIDiscoveryURL\":null,\"HasConfigurationSettings\":false,\"ConfigFilePath\":null},\"Philote\":{\"ID\":\"32f1f64a-76a2-4212-9950-0efe2858ba4a\",\"AdditionalIDs\":{},\"TimeBlocks\":[]}}" ) };

      // ToDo: Add the Miner program with the status log files
      // ToDo: Add the old Dos/Windows CMD processor
      // ToDo: Add Linux shells

    }
    public IEnumerator<object[]> GetEnumerator() { return TestData().GetEnumerator(); }
    IEnumerator IEnumerable.GetEnumerator() { return GetEnumerator(); }
  }
}
