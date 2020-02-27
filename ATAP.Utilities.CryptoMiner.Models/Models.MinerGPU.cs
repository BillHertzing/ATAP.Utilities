using ATAP.Utilities.ComputerInventory;
using ATAP.Utilities.ComputerInventory.Enumerations;
using ATAP.Utilities.ComputerInventory.Configuration;
using ATAP.Utilities.CryptoCoin;
using ATAP.Utilities.CryptoCoin.Models;
using ATAP.Utilities.CryptoCoin.Enumerations;
using ATAP.Utilities.CryptoMiner.Enumerations;
using ATAP.Utilities.ConcurrentObservableCollections;
using System;
using System.Collections.Generic;
using System.Text;
using ATAP.Utilities.ComputerInventory.Configuration.Hardware;
using ATAP.Utilities.ComputerInventory.Interfaces.Hardware;
using ATAP.Utilities.CryptoMiner.Interfaces;
using UnitsNet;
using UnitsNet.Units;
using ATAP.Utilities.CryptoCoin.Interfaces;

namespace ATAP.Utilities.CryptoMiner.Models
{
  public class MinerGPU : VideoCard, IMinerGPU
  {
    public MinerGPU() : base()
    {
    }

    public MinerGPU(string bIOSVersion, Frequency coreClock, ElectricPotentialDcUnit coreVoltage, string deviceID, ConcurrentObservableDictionary<Coin, IHashRate> hashRatePerCoin, bool isStrapped, Frequency memClock, PowerUnit powerLimit, IVideoCardDiscriminatingCharacteristics videoCardDiscriminatingCharacteristics) : base(bIOSVersion, coreClock, coreVoltage, deviceID, isStrapped, memClock, powerLimit, videoCardDiscriminatingCharacteristics)
    {
      HashRatePerCoin = hashRatePerCoin;
    }

    public ConcurrentObservableDictionary<Coin, IHashRate> HashRatePerCoin { get; }
  }

}
