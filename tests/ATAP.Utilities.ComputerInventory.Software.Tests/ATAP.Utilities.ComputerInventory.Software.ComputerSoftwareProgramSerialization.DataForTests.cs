using System.Collections.Generic;
using System.Collections;
using System;
using ATAP.Utilities.ComputerInventory.Software;
using ATAP.Utilities.Testing;

namespace ATAP.Utilities.ComputerInventory.Software.Tests {

  //ToDo add validation tests to ensure illegal values are not allowed.  This applies to all XxTestDataGenerator classes
  public class ComputerSoftwareSerializationProgramTestData {

    public ComputerSoftwareProgram ObjTestData { get; }
    public string SerializedTestData { get; }

    public ComputerSoftwareSerializationProgramTestData(ComputerSoftwareProgram objTestData, string serializedTestData) {
      ObjTestData = objTestData ?? throw new ArgumentNullException(nameof(objTestData));
      SerializedTestData = serializedTestData ?? throw new ArgumentNullException(nameof(serializedTestData));
    }
  }

  public class ComputerSoftwareProgramSerializationTestDataGenerator : IEnumerable<object[]> {

    public static IEnumerable<object[]> TestData() {

      yield return new ComputerSoftwareSerializationProgramTestData[] {
        new ComputerSoftwareSerializationProgramTestData(
          new ComputerSoftwareProgram(DefaultConfiguration.Production["Generic"] ),
          "{\"ComputerSoftwareProgramSignil\":{\"ProcessName\":\"Generic\",\"ProcessPath\":\".\",\"ProcessStartPath\":\".\",\"Version\":\"0.0.0\",\"HasSTDOut\":true,\"HasERROut\":true,\"HasLogFiles\":true,\"LogFileFolder\":\".\",\"LogFileFnPattern\":\".log\",\"HasAPI\":false,\"APIDiscoveryURL\":null,\"HasConfigurationSettings\":false,\"ConfigFilePath\":null}}" ) };
      yield return new ComputerSoftwareSerializationProgramTestData[] {
        new ComputerSoftwareSerializationProgramTestData(
          new ComputerSoftwareProgram(DefaultConfiguration.Production["PowerShell"] ),
        "{\"ComputerSoftwareProgramSignil\":{\"ProcessName\":\"powershell\",\"ProcessPath\":\"C:\\\\Windows\\\\System32\\\\WindowsPowerShell\\\\v1.0\\\\powershell.exe\",\"ProcessStartPath\":\".\",\"Version\":\"v5\",\"HasSTDOut\":true,\"HasERROut\":true,\"HasLogFiles\":true,\"LogFileFolder\":\".\",\"LogFileFnPattern\":\".log\",\"HasAPI\":false,\"APIDiscoveryURL\":null,\"HasConfigurationSettings\":false,\"ConfigFilePath\":null}}" ) };
      yield return new ComputerSoftwareSerializationProgramTestData[] {
        new ComputerSoftwareSerializationProgramTestData(
          new ComputerSoftwareProgram(DefaultConfiguration.Production["dotnet"] ),
        "{\"ComputerSoftwareProgramSignil\":{\"ProcessName\":\"dotnet\",\"ProcessPath\":\"C:\\\\Windows\\\\dotnet.exe\",\"ProcessStartPath\":\".\",\"Version\":\"v16\",\"HasSTDOut\":true,\"HasERROut\":true,\"HasLogFiles\":true,\"LogFileFolder\":\".\",\"LogFileFnPattern\":\".log\",\"HasAPI\":false,\"APIDiscoveryURL\":null,\"HasConfigurationSettings\":false,\"ConfigFilePath\":null}}" ) };
      yield return new ComputerSoftwareSerializationProgramTestData[] {
        new ComputerSoftwareSerializationProgramTestData(
          new ComputerSoftwareProgram(DefaultConfiguration.Production["EthDCRMiner"] ),
        "{\"ComputerSoftwareProgramSignil\":{\"ProcessName\":\"EthDCRMiner\",\"ProcessPath\":\"C:\\\\\",\"ProcessStartPath\":\".\",\"Version\":\"v1\",\"HasSTDOut\":false,\"HasERROut\":false,\"HasLogFiles\":false,\"LogFileFolder\":\".\",\"LogFileFnPattern\":\".log\",\"HasAPI\":false,\"APIDiscoveryURL\":null,\"HasConfigurationSettings\":false,\"ConfigFilePath\":null}}" ) };

      // ToDo: Add the Miner program with the status log files
      // ToDo: Add the old Dos/Windows CMD processor
      // ToDo: Add Linux shells

    }
    public IEnumerator<object[]> GetEnumerator() { return TestData().GetEnumerator(); }
    IEnumerator IEnumerable.GetEnumerator() { return GetEnumerator(); }
  }
}
