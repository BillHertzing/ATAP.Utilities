using System.Collections.Generic;
using System.Collections;
using System;
using ATAP.Utilities.ComputerInventory.Hardware;

namespace ATAP.Utilities.ComputerInventory.Hardware.UnitTests
{
  //ToDo add validation tests to ensure illegal values are not allowed.  This applies to all XxTestDataGenerator classes
  public class VideoCardSignilTestData
  {
    public VideoCardSignil VideoCardSignil;
    public string SerializedVideoCardSignil;

    public VideoCardSignilTestData()
    {
    }

    public VideoCardSignilTestData(VideoCardSignil videoCardSignil, string serializedVideoCardSignil)
    {
      VideoCardSignil = videoCardSignil ?? throw new ArgumentNullException(nameof(videoCardSignil));
      SerializedVideoCardSignil = serializedVideoCardSignil ?? throw new ArgumentNullException(nameof(serializedVideoCardSignil));
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
  public class VideoCardSignilTestDataGenerator : IEnumerable<object[]>
  {
    public static IEnumerable<object[]> VideoCardSignilTestData()
    {
      yield return new VideoCardSignilTestData[] { new VideoCardSignilTestData { VideoCardSignil = new VideoCardSignil(
        ), SerializedVideoCardSignil = "{\"Maker\":0}" } };
      yield return new VideoCardSignilTestData[] { new VideoCardSignilTestData { VideoCardSignil = new VideoCardSignil(
        ), SerializedVideoCardSignil = "{\"Maker\":1}" } };
      yield return new VideoCardSignilTestData[] { new VideoCardSignilTestData { VideoCardSignil = new VideoCardSignil(
        ), SerializedVideoCardSignil = "{\"Maker\":2}" } };
    }
    public IEnumerator<object[]> GetEnumerator() { return VideoCardSignilTestData().GetEnumerator(); }
    IEnumerator IEnumerable.GetEnumerator() { return GetEnumerator(); }
  }
}
