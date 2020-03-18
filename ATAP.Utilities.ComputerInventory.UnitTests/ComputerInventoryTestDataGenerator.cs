using System;
using System.Collections.Generic;
using System.Collections;
using ATAP.Utilities.ComputerInventory;
using ATAP.Utilities.ComputerInventory.Hardware;
using ATAP.Utilities.ComputerInventory.ProcessInfo;
using ATAP.Utilities.ComputerInventory.Software;


namespace ATAP.Utilities.ComputerInventory.UnitTests
{

  //ToDo add validation tests to ensure illegal values are not allowed.  This applies to all XxTestDataGenerator classes
  public class ComputerInventoryTestData
  {
    public ComputerInventory ComputerInventory;
    public string SerializedComputerInventory;

    public ComputerInventoryTestData()
    {
    }

    public ComputerInventoryTestData(ComputerInventory computerInventory, string serializedComputerInventory)
    {
      ComputerInventory = computerInventory ?? throw new ArgumentNullException(nameof(computerInventory));
      SerializedComputerInventory = serializedComputerInventory ?? throw new ArgumentNullException(nameof(serializedComputerInventory));
    }
  }
  /*
   *       var computerInventory = new ComputerInventory("EthDCRMiner",
                                                                @"C:\",
                                                                @"C:\",
                                                                "10.2",
                                                                false,
                                                                null,
                                                                null,
                                                                false,
                                                                null,
                                                                null,
                                                                false,
                                                                false,
                                                                false);

ComputerInventory powerShell = new ComputerInventory("powershell",
                                                                       @"C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe",
                                                                       ".",
                                                                       "v5",
                                                                       false,
                                                                       null,
                                                                       null,
                                                                       false,
                                                                       null,
                                                                       null,
                                                                       false,
                                                                       false,
                                                                       false);

     ComputerInventory powerShell = new ComputerInventory("powershell",
                                                                       @"C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe",
                                                                       ".",
                                                                       "v5",
                                                                       false,
                                                                       null,
                                                                       null,
                                                                       false,
                                                                       null,
                                                                       null,
                                                                       false,
                                                                       false,
                                                                       false);

    [InlineData("{\"ComputerHardware\":{\"Computer\":{\"MainboardEnabled\":true,\"CPUEnabled\":true,\"RAMEnabled\":false,\"GPUEnabled\":true,\"FanControllerEnabled\":true,\"HDDEnabled\":false,\"Hardware\":[]},\"CPUs\":[{\"Maker\":\"Intel\"}],\"MainBoard\":{\"Maker\":\"ASUS\",\"Socket\":\"ToDo:makeSocketanEnum\"},\"VideoCards\":[{\"BIOSVersion\":\"ToDo:readfromcard\",\"CoreClock\":-1.0,\"CoreVoltage\":-1.0,\"DeviceID\":\"ToDo:readfromcard\",\"IsStrapped\":false,\"MemClock\":-1.0,\"PowerConsumption\":{\"Period\":\"00:01:00\",\"Watts\":1000.0},\"PowerLimit\":-1.0,\"TempAndFan\":{\"Temp\":60.0,\"FanPct\":50.0},\"VideoCardSignil\":{\"CardName\":\"GTX 980 TI\",\"GPUMaker\":\"NVIDEA\",\"VideoCardMaker\":\"ASUS\",\"VideoMemoryMaker\":\"Samsung\",\"VideoMemorySize\":6144}}],\"IsMainboardEnabled\":true,\"IsCPUsEnabled\":true,\"IsVideoCardsEnabled\":true,\"IsFanControllerEnabled\":true,\"MainboardEnabled\":false,\"CPUEnabled\":false,\"RAMEnabled\":false,\"GPUEnabled\":false,\"FanControllerEnabled\":false,\"HDDEnabled\":false,\"Hardware\":[]},\"ComputerSoftware\":{\"ComputerSoftwareDrivers\":[{\"Name\":\"genericvideo\",\"Version\":\"1.0\"},{\"Name\":\"AMDVideoDriver\",\"Version\":\"1.0\"},{\"Name\":\"NVideaVideoDriver\",\"Version\":\"1.0\"}],\"ComputerSoftwarePrograms\":[{\"ProcessName\":\"EthDCRMiner\",\"ProcessPath\":\"C:\\\\\",\"ProcessStartPath\":\"C:\\\\\",\"Version\":\"10.2\",\"HasConfigurationSettings\":false,\"ConfigurationSettings\":null,\"ConfigFilePath\":null,\"HasLogFiles\":false,\"LogFileFolder\":null,\"LogFileFnPattern\":null,\"HasAPI\":false,\"HasSTDOut\":false,\"HasERROut\":false}]},\"ComputerProcesses\":{}}")]
    
          mainBoard = new MainBoard(MainBoardMaker.ASUS, CPUSocket.LGA1155);
      cPU = new CPU(CPUMaker.Intel);
      cPUs = new CPU[1];
      cPUs[0] = cPU;
      videoCardSignil = VideoCardsKnownDefaultConfiguration.TuningParameters.Keys.Where(x =>
 (x.VideoCardMaker == VideoCardMaker.ASUS && x.GPUMaker == GPUMaker.NVIDEA))
                                                                                              .Single();
      videoCard = new VideoCard(videoCardSignil,
                     "ToDo:readfromcard",
                     "ToDo:readfromcard",
                     false,
                     -1,
                     -1,
                     -1,
                     -1
                     );
      videoCards = new VideoCard[1];
      videoCards[0] = videoCard;
      videoCardSensorData = new VideoCardSensorData(1000.0, 1333.0, 1.0, 1.0, 500.0, 85.0, 100.0);
      computerHardware = new ComputerHardware(new CPU[1] { new CPU(CPUMaker.Intel) }, MainBoard, new VideoCard[1] { videoCard });


  */
  public class ComputerInventoryTestDataGenerator : IEnumerable<object[]>
  {
    public static IEnumerable<object[]> TestData()
    {
      yield return new ComputerInventoryTestData[] { new ComputerInventoryTestData { ComputerInventory = new ComputerInventory(
        new ComputerHardware(),
        new ComputerSoftware(),
        new ComputerProcesses()
        ), SerializedComputerInventory = "{\"Maker\":0}" } };
      yield return new ComputerInventoryTestData[] { new ComputerInventoryTestData { ComputerInventory = new ComputerInventory(
        new ComputerHardware(),
        new ComputerSoftware(),
        new ComputerProcesses()        ), SerializedComputerInventory = "{\"Maker\":1}" } };
      yield return new ComputerInventoryTestData[] { new ComputerInventoryTestData { ComputerInventory = new ComputerInventory(
        new ComputerHardware(),
        new ComputerSoftware(),
        new ComputerProcesses()        ), SerializedComputerInventory = "{\"Maker\":2}" } };
    }
    public IEnumerator<object[]> GetEnumerator() { return TestData().GetEnumerator(); }
    IEnumerator IEnumerable.GetEnumerator() { return GetEnumerator(); }
  }
}
