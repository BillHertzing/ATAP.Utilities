using System.Collections.Generic;
using System.Collections;
using System;
using ATAP.Utilities.ComputerInventory.Software;
using ATAP.Utilities.Testing;
using System.Text.RegularExpressions;
using System.Resources;

namespace ATAP.Utilities.ComputerInventory.Software.UnitTests {

  //ToDo add validation tests to ensure illegal values are not allowed.  This applies to all XxTestDataGenerator classes
  public class ComputerSoftwareSerializationProgramTestData : TestData<ComputerSoftwareProgram> {

    public ComputerSoftwareSerializationProgramTestData(ComputerSoftwareProgram objTestData, string serializedTestData) : base(objTestData, serializedTestData) {
    }
  }

  public class ComputerSoftwareProgramSerializationTestDataGenerator : IEnumerable<object[]> {

    public static IEnumerable<object[]> TestData() {
      ResourceManager rm = new ResourceManager("ATAP.Utilities.ComputerInventory.Software.UnitTests.SerializationStrings", typeof(SerializationStrings).Assembly);
      
      yield return new ComputerSoftwareSerializationProgramTestData[] {
        new ComputerSoftwareSerializationProgramTestData(
          new ComputerSoftwareProgram(DefaultConfiguration.Production["Generic"],
          new Philote.Philote<IComputerSoftwareProgram>()),
          rm.GetString("SerializedComputerSoftwareProgramGenericPart1") + 
        "[0-9A-Fa-f]{8}-?([0-9A-Fa-f]{4}-?){3}[0-9A-Fa-f]{12}" +
        rm.GetString("SerializedComputerSoftwareProgramGenericPart1") ) };
      yield return new ComputerSoftwareSerializationProgramTestData[] {
        new ComputerSoftwareSerializationProgramTestData(
          new ComputerSoftwareProgram(DefaultConfiguration.Production["PowerShell"],
          new Philote.Philote<IComputerSoftwareProgram>()),
        "{\"ComputerSoftwareProgramSignil\":{\"ProcessName\":\"powershell\",\"ProcessPath\":\"C:\\\\Windows\\\\System32\\\\WindowsPowerShell\\\\v1.0\\\\powershell.exe\",\"ProcessStartPath\":\".\",\"Version\":\"v5\",\"HasSTDOut\":true,\"HasERROut\":true,\"HasLogFiles\":true,\"LogFileFolder\":\".\",\"LogFileFnPattern\":\".log\",\"HasAPI\":false,\"APIDiscoveryURL\":null,\"HasConfigurationSettings\":false,\"ConfigFilePath\":null},\"Philote\":{\"ID\":\"[0-9A-Fa-f]{8}-?([0-9A-Fa-f]{4}-?){3}[0-9A-Fa-f]{12}\",\"AdditionalIDs\":{},\"TimeBlocks\":[]}}" ) };
      yield return new ComputerSoftwareSerializationProgramTestData[] {
        new ComputerSoftwareSerializationProgramTestData(
          new ComputerSoftwareProgram(DefaultConfiguration.Production["dotnet"],
          new Philote.Philote<IComputerSoftwareProgram>()),
        "{\"ComputerSoftwareProgramSignil\":{\"ProcessName\":\"dotnet\",\"ProcessPath\":\"C:\\\\Windows\\\\dotnet.exe\",\"ProcessStartPath\":\".\",\"Version\":\"v16\",\"HasSTDOut\":true,\"HasERROut\":true,\"HasLogFiles\":true,\"LogFileFolder\":\".\",\"LogFileFnPattern\":\".log\",\"HasAPI\":false,\"APIDiscoveryURL\":null,\"HasConfigurationSettings\":false,\"ConfigFilePath\":null},\"Philote\":{\"ID\":\"cbc87719-69ce-4ebf-933b-94a208450a34\",\"AdditionalIDs\":{},\"TimeBlocks\":[]}}" ) };
      yield return new ComputerSoftwareSerializationProgramTestData[] {
        new ComputerSoftwareSerializationProgramTestData(
          new ComputerSoftwareProgram(DefaultConfiguration.Production["EthDCRMiner"],
          new Philote.Philote<IComputerSoftwareProgram>()),
        "{\"ComputerSoftwareProgramSignil\":{\"ProcessName\":\"EthDCRMiner\",\"ProcessPath\":\"C:\\\\\",\"ProcessStartPath\":\".\",\"Version\":\"v1\",\"HasSTDOut\":false,\"HasERROut\":false,\"HasLogFiles\":false,\"LogFileFolder\":\".\",\"LogFileFnPattern\":\".log\",\"HasAPI\":false,\"APIDiscoveryURL\":null,\"HasConfigurationSettings\":false,\"ConfigFilePath\":null},\"Philote\":{\"ID\":\"[0-9A-Fa-f]{8}-?([0-9A-Fa-f]{4}-?){3}[0-9A-Fa-f]{12}\",\"AdditionalIDs\":{},\"TimeBlocks\":[]}}" ) };

      // ToDo: Add the Miner program with the status log files
      // ToDo: Add the old Dos/Windows CMD processor
      // ToDo: Add Linux shells

    }
    public IEnumerator<object[]> GetEnumerator() { return TestData().GetEnumerator(); }
    IEnumerator IEnumerable.GetEnumerator() { return GetEnumerator(); }
  }
}
