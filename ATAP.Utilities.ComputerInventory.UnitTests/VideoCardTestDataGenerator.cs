using System.Collections.Generic;
using System.Collections;
using ATAP.Utilities.ComputerInventory.Configuration.Hardware;
using System;
using ATAP.Utilities.ComputerInventory.Models.Hardware;
using UnitsNet;
using UnitsNet.Units;

namespace ATAP.Utilities.ComputerInventory.UnitTests
{
  //ToDo add validation tests to ensure illegal values are not allowed.  This applies to all XxTestDataGenerator classes
  public class VideoCardTestData
  {
    public VideoCard VideoCard;
    public string SerializedVideoCard;

    public VideoCardTestData()
    {
    }

    public VideoCardTestData(VideoCard videoCard, string serializedVideoCard)
    {
      VideoCard = videoCard ?? throw new ArgumentNullException(nameof(videoCard));
      SerializedVideoCard = serializedVideoCard ?? throw new ArgumentNullException(nameof(serializedVideoCard));
    }
  }

  //[InlineData("{\"BIOSVersion\":\"100.00001.02320.00\",\"CardName\":\"GTX 980 TI\",\"CoreClock\":1140.0,\"CoreVoltage\":11.13,\"DeviceID\":\"10DE 17C8 - 3842\",\"IsStrapped\":false,\"MemClock\":1753.0,\"PowerConsumption\":{\"Period\":\"00:01:00\",\"Watts\":1000.0},\"PowerLimit\":0.8,\"TempAndFan\":{\"Temp\":60.0,\"FanPct\":50.0},\"VideoCardMaker\":\"ASUS\",\"GPUMaker\":\"NVIDEA\"}")]

  /*
   *   VideoCardSignil vcdc = VideoCardsKnownDefaultConfiguration.TuningParameters.Keys.Where(x => (x.VideoCardMaker ==
VideoCardMaker.ASUS
&& x.GPUMaker ==
GPUMaker.NVIDEA))

   *       VideoCard videoCard = new VideoCard(vcdc,
                                        "10DE 17C8 - 3842",
                                        "100.00001.02320.00",
                                        false,
                                        1140,
                                        1753,
                                        11.13,
                                        0.8);


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


        [InlineData("{\"BIOSVersion\":\"100.00001.02320.00\",\"CoreClock\":1140.0,\"CoreVoltage\":11.13,\"DeviceID\":\"10DE 17C8 - 3842\",\"IsStrapped\":false,\"MemClock\":1753.0,\"PowerLimit\":0.8,\"VideoCardSignil\":{\"CardName\":\"GTX 980 TI\",\"GPUMaker\":\"NVIDEA\",\"VideoCardMaker\":\"ASUS\",\"VideoMemoryMaker\":\"Samsung\",\"VideoMemorySize\":6144}}")]
 VideoCardSignil vcdc = VideoCardsKnownDefaultConfiguration.TuningParameters.Keys.Where(x => (x.VideoCardMaker ==
VideoCardMaker.ASUS
&& x.GPUMaker ==
GPUMaker.NVIDEA))
                                                        .Single();
      VideoCard videoCard = new VideoCard(vcdc,
                                          "10DE 17C8 - 3842",
                                          "100.00001.02320.00",
                                          false,
                                          1140,
                                          1753,
                                          11.13,
                                          0.8);
  */
  public class VideoCardTestDataGenerator : IEnumerable<object[]>
  {
    public static IEnumerable<object[]> VideoCardTestData()
    {
      yield return new VideoCardTestData[] { new VideoCardTestData {
        VideoCard = new VideoCard(
          "100.00001.02320.00",
          new Frequency(1140,FrequencyUnit.Megahertz),
          new ElectricPotentialDc(11.13,ElectricPotentialDcUnit.VoltDc),
          "10DE 17C8 - 3842",
          false,
          new Frequency(1753, FrequencyUnit.Megahertz),
          new PowerConsumption(new TimeSpan(0,1,0), new Power(0.8m,PowerUnit.Watt)),
          new VideoCardSignil(
            )
        ),
        SerializedVideoCard = "{\"BIOSVersion\":\"100.00001.02320.00\",\"CoreClock\":1140.0,\"CoreVoltage\":11.13,\"DeviceID\":\"10DE 17C8 - 3842\",\"IsStrapped\":false,\"MemClock\":1753.0,\"PowerLimit\":0.8,\"VideoCardSignil\":{\"CardName\":\"GTX 980 TI\",\"GPUMaker\":\"NVIDEA\",\"VideoCardMaker\":\"ASUS\",\"VideoMemoryMaker\":\"Samsung\",\"VideoMemorySize\":6144}"
      }
  };
      yield return new VideoCardTestData[] { new VideoCardTestData { VideoCard = new VideoCard(
    ), SerializedVideoCard = "{\"BIOSVersion\":null,\"CoreClock\":\"0 Hz\",\"CoreVoltage\":0,\"DeviceID\":null,\"IsStrapped\":false,\"MemClock\":\"0 Hz\",\"PowerLimit\":0,\"VideoCardSignil\":null}" } };
    }

    public IEnumerator<object[]> GetEnumerator() { return VideoCardTestData().GetEnumerator(); }
    IEnumerator IEnumerable.GetEnumerator() { return GetEnumerator(); }
  }
}
