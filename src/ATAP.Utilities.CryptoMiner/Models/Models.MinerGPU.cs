using ATAP.Utilities.CryptoCoin.Enumerations;
using ATAP.Utilities.ConcurrentObservableCollections;
using ATAP.Utilities.CryptoMiner.Interfaces;
using UnitsNet;
using ATAP.Utilities.CryptoCoin.Interfaces;
using ATAP.Utilities.ComputerInventory.Hardware;

namespace ATAP.Utilities.CryptoMiner.Models
{
  public class MinerGPU : VideoCard, IMinerGPU
  {
    public MinerGPU() : base()
    {
    }

    public MinerGPU(string bIOSVersion, Frequency coreClock, ElectricPotentialDc coreVoltage, string deviceID, ConcurrentObservableDictionary<Coin, IHashRate> hashRatePerCoin, bool isStrapped, Frequency memClock, IPowerConsumption powerConsumption, IVideoCardSignil videoCardSignil) : base(bIOSVersion, coreClock, coreVoltage, deviceID, isStrapped, memClock, powerConsumption, videoCardSignil)
    {
      HashRatePerCoin = hashRatePerCoin;
    }

    public ConcurrentObservableDictionary<Coin, IHashRate> HashRatePerCoin { get; }
  }

}
