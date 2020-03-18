using System.Collections.Generic;
using System.Collections;
using ATAP.Utilities.ComputerInventory;
using ATAP.Utilities.ComputerInventory.Hardware;
using ATAP.Utilities.ComputerInventory.ProcessInfo;
using ATAP.Utilities.ComputerInventory.Software;
using System;
using ATAP.Utilities.ComputerInventory.Configuration;

namespace ATAP.Utilities.ComputerInventory.UnitTests
{
  /*
  //ToDo add validation tests to ensure illegal values are not allowed.  This applies to all XxTestDataGenerator classes
  public class DefaultConfigurationTestData
  {
    public string SerializedDefaultConfiguration;

    public DefaultConfigurationTestData()
    {
    }

    public DefaultConfigurationTestData(string serializedDefaultConfiguration)
    {
      SerializedDefaultConfiguration = serializedDefaultConfiguration ?? throw new ArgumentNullException(nameof(serializedDefaultConfiguration));
    }
  }

  public class DefaultConfigurationTestDataGenerator : IEnumerable<object[]>
  {
    public static IEnumerable<object[]> DefaultConfigurationTestData()
    {
      yield return new DefaultConfigurationTestData[] { new DefaultConfigurationTestData { SerializedDefaultConfiguration = "{\"Maker\":0}" } };
      yield return new DefaultConfigurationTestData[] { new DefaultConfigurationTestData { SerializedDefaultConfiguration = "{\"Maker\":1}" } };
      yield return new DefaultConfigurationTestData[] { new DefaultConfigurationTestData { SerializedDefaultConfiguration = "{\"Maker\":2}" } };
    }
    public IEnumerator<object[]> GetEnumerator() { return DefaultConfigurationTestData().GetEnumerator(); }
    IEnumerator IEnumerable.GetEnumerator() { return GetEnumerator(); }
  }

  public class DefaultConfigurationHardwareTestData
  {
    public CPU CPU;
    public CPU[] CPUArray;
    public CPUSocket CPUSocket;
    public MainBoard MainBoard;
    public VideoCardSignil VideoCardSignil;
    public VideoCard VideoCard;
    public VideoCard[] VideoCardArray;

    public DefaultConfigurationHardwareTestData()
    {
    }

    public DefaultConfigurationHardwareTestData(CPU cPU, CPU[] cPUArray, CPUSocket cPUSocket, MainBoard mainBoard, VideoCardSignil videoCardSignil, VideoCard videoCard, VideoCard[] videoCardArray)
    {
      CPU = cPU ?? throw new ArgumentNullException(nameof(cPU));
      CPUArray = cPUArray ?? throw new ArgumentNullException(nameof(cPUArray));
      CPUSocket = cPUSocket;
      MainBoard = mainBoard ?? throw new ArgumentNullException(nameof(mainBoard));
      VideoCardSignil = videoCardSignil ?? throw new ArgumentNullException(nameof(videoCardSignil));
      VideoCard = videoCard ?? throw new ArgumentNullException(nameof(videoCard));
      VideoCardArray = videoCardArray ?? throw new ArgumentNullException(nameof(videoCardArray));
    }
  }

  public class DefaultConfigurationHardwareTestDataGenerator : IEnumerable<object[]>
  {
    public static IEnumerable<object[]> DefaultConfigurationHardwareTestData()
    {
      yield return new DefaultConfigurationHardwareTestData[] { new DefaultConfigurationHardwareTestData {
        CPU = new CPU(CPUMaker.Generic),
        CPUArray = new CPU[1] { new CPU(CPUMaker.Generic) },
        CPUSocket = CPUSocket.Generic,
        MainBoard = new MainBoard(MainBoardMaker.Generic, CPUSocket.Generic ),
        VideoCardSignil = new VideoCardSignil("generic",GPUMaker.Generic,VideoCardMaker.Generic,VideoCardMemoryMaker.Generic,4096),
        VideoCard = new VideoCard(),
        VideoCardArray = new VideoCard[1] {new VideoCard() }
      }
      };
    }
    public IEnumerator<object[]> GetEnumerator() { return DefaultConfigurationHardwareTestData().GetEnumerator(); }
    IEnumerator IEnumerable.GetEnumerator() { return GetEnumerator(); }
  }
  */

}
