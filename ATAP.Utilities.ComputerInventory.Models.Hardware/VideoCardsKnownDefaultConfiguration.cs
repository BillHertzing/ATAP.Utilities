using ATAP.Utilities.ComputerInventory.Enumerations;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using UnitsNet.Units;

namespace ATAP.Utilities.ComputerInventory.Configuration.Hardware
{
  [Serializable]
  public static class VideoCardsKnownDefaultConfiguration
  {
    public static Dictionary<VideoCardDiscriminatingCharacteristics, VideoCardTuningParameters> TuningParameters { get; }

    static VideoCardsKnownDefaultConfiguration()
    {
      TuningParameters = new Dictionary<VideoCardDiscriminatingCharacteristics, VideoCardTuningParameters>
      {
          { new VideoCardDiscriminatingCharacteristics(
            "GTX 980 TI",
            GPUMaker.NVIDEA,
            VideoCardMaker.ASUS,
            VideoCardMemoryMaker.Samsung,
            6144),
            new VideoCardTuningParameters(
              new UnitsNet.Frequency(810, FrequencyUnit.Megahertz),
              new UnitsNet.Frequency(800, FrequencyUnit.Megahertz),
              new UnitsNet.Frequency(820, FrequencyUnit.Megahertz),
              new UnitsNet.Frequency(405, FrequencyUnit.Megahertz),
              new UnitsNet.Frequency(400, FrequencyUnit.Megahertz),
              new UnitsNet.Frequency(410, FrequencyUnit.Megahertz),
              new UnitsNet.ElectricPotentialDc(0.862, ElectricPotentialDcUnit.VoltDc),
              new UnitsNet.ElectricPotentialDc(0.80, ElectricPotentialDcUnit.VoltDc),
              new UnitsNet.ElectricPotentialDc(1.024, ElectricPotentialDcUnit.VoltDc)) },
          { new VideoCardDiscriminatingCharacteristics(
              "R9 270",
              GPUMaker.AMD,
              VideoCardMaker.MSI,
              VideoCardMemoryMaker.Elpida,
              2048),
            new VideoCardTuningParameters(
              new UnitsNet.Frequency(1400, FrequencyUnit.Megahertz),
              new UnitsNet.Frequency(1300, FrequencyUnit.Megahertz),
              new UnitsNet.Frequency(1500, FrequencyUnit.Megahertz),
              new UnitsNet.Frequency(955, FrequencyUnit.Megahertz),
              new UnitsNet.Frequency(940, FrequencyUnit.Megahertz),
              new UnitsNet.Frequency(960, FrequencyUnit.Megahertz),
              new UnitsNet.ElectricPotentialDc(1.0, ElectricPotentialDcUnit.VoltDc),
              new UnitsNet.ElectricPotentialDc(0.98, ElectricPotentialDcUnit.VoltDc),
              new UnitsNet.ElectricPotentialDc(1.05, ElectricPotentialDcUnit.VoltDc)) },
          { new VideoCardDiscriminatingCharacteristics(
              "RX 580",
              GPUMaker.AMD,
              VideoCardMaker.MSI,
              VideoCardMemoryMaker.Hynix,
              8192),
            new VideoCardTuningParameters(
              new UnitsNet.Frequency(1400, FrequencyUnit.Megahertz),
              new UnitsNet.Frequency(1300, FrequencyUnit.Megahertz),
              new UnitsNet.Frequency(1500, FrequencyUnit.Megahertz),
              new UnitsNet.Frequency(955, FrequencyUnit.Megahertz),
              new UnitsNet.Frequency(940, FrequencyUnit.Megahertz),
              new UnitsNet.Frequency(960, FrequencyUnit.Megahertz),
              new UnitsNet.ElectricPotentialDc(1.0, ElectricPotentialDcUnit.VoltDc),
              new UnitsNet.ElectricPotentialDc(0.98, ElectricPotentialDcUnit.VoltDc),
              new UnitsNet.ElectricPotentialDc(1.05, ElectricPotentialDcUnit.VoltDc)) },
          { new VideoCardDiscriminatingCharacteristics(
              "RX 580",
              GPUMaker.AMD,
              VideoCardMaker.MSI,
              VideoCardMemoryMaker.Generic,
              8192),
            new VideoCardTuningParameters(
              new UnitsNet.Frequency(1400, FrequencyUnit.Megahertz),
              new UnitsNet.Frequency(1300, FrequencyUnit.Megahertz),
              new UnitsNet.Frequency(1500, FrequencyUnit.Megahertz),
              new UnitsNet.Frequency(955, FrequencyUnit.Megahertz),
              new UnitsNet.Frequency(940, FrequencyUnit.Megahertz),
              new UnitsNet.Frequency(960, FrequencyUnit.Megahertz),
              new UnitsNet.ElectricPotentialDc(1.0, ElectricPotentialDcUnit.VoltDc),
              new UnitsNet.ElectricPotentialDc(0.98, ElectricPotentialDcUnit.VoltDc),
              new UnitsNet.ElectricPotentialDc(1.05, ElectricPotentialDcUnit.VoltDc)) },
          { new VideoCardDiscriminatingCharacteristics(
              "RX 580",
              GPUMaker.AMD,
              VideoCardMaker.PowerColor,
              VideoCardMemoryMaker.Hynix,
              8192),
            new VideoCardTuningParameters(
              new UnitsNet.Frequency(1400, FrequencyUnit.Megahertz),
              new UnitsNet.Frequency(1300, FrequencyUnit.Megahertz),
              new UnitsNet.Frequency(1500, FrequencyUnit.Megahertz),
              new UnitsNet.Frequency(955, FrequencyUnit.Megahertz),
              new UnitsNet.Frequency(940, FrequencyUnit.Megahertz),
              new UnitsNet.Frequency(960, FrequencyUnit.Megahertz),
              new UnitsNet.ElectricPotentialDc(1.0, ElectricPotentialDcUnit.VoltDc),
              new UnitsNet.ElectricPotentialDc(0.98, ElectricPotentialDcUnit.VoltDc),
              new UnitsNet.ElectricPotentialDc(1.05, ElectricPotentialDcUnit.VoltDc)) },
          { new VideoCardDiscriminatingCharacteristics(
              "RX 580",
              GPUMaker.AMD,
              VideoCardMaker.PowerColor,
              VideoCardMemoryMaker.Samsung,
              8192),
            new VideoCardTuningParameters(
              new UnitsNet.Frequency(1400, FrequencyUnit.Megahertz),
              new UnitsNet.Frequency(1300, FrequencyUnit.Megahertz),
              new UnitsNet.Frequency(1500, FrequencyUnit.Megahertz),
              new UnitsNet.Frequency(955, FrequencyUnit.Megahertz),
              new UnitsNet.Frequency(940, FrequencyUnit.Megahertz),
              new UnitsNet.Frequency(960, FrequencyUnit.Megahertz),
              new UnitsNet.ElectricPotentialDc(1.0, ElectricPotentialDcUnit.VoltDc),
              new UnitsNet.ElectricPotentialDc(0.98, ElectricPotentialDcUnit.VoltDc),
              new UnitsNet.ElectricPotentialDc(1.05, ElectricPotentialDcUnit.VoltDc))},
          { new VideoCardDiscriminatingCharacteristics(
              "Generic",
              GPUMaker.Generic,
              VideoCardMaker.Generic,
              VideoCardMemoryMaker.Generic,
              1024),
            new VideoCardTuningParameters(
              new UnitsNet.Frequency(1000, FrequencyUnit.Megahertz),
              new UnitsNet.Frequency(500, FrequencyUnit.Megahertz),
              new UnitsNet.Frequency(1500, FrequencyUnit.Megahertz),
              new UnitsNet.Frequency(955, FrequencyUnit.Megahertz),
              new UnitsNet.Frequency(940, FrequencyUnit.Megahertz),
              new UnitsNet.Frequency(960, FrequencyUnit.Megahertz),
              new UnitsNet.ElectricPotentialDc(1.0, ElectricPotentialDcUnit.VoltDc),
              new UnitsNet.ElectricPotentialDc(0.98, ElectricPotentialDcUnit.VoltDc),
              new UnitsNet.ElectricPotentialDc(1.05, ElectricPotentialDcUnit.VoltDc))}
      };
    }
  }

}
