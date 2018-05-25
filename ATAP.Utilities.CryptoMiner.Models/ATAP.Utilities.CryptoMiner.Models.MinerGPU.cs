using ATAP.Utilities.ComputerInventory;
using ATAP.Utilities.ComputerInventory.Enumerations;
using ATAP.Utilities.ComputerInventory.Models;
using ATAP.Utilities.CryptoCoin;
using ATAP.Utilities.CryptoCoin.Models;
using ATAP.Utilities.CryptoCoin.Enumerations;
using ATAP.Utilities.CryptoMiner.Enumerations;
using Swordfish.NET.Collections;
using System;
using System.Collections.Generic;
using System.Text;

namespace ATAP.Utilities.CryptoMiner.Models
{
    public class MinerGPU : VideoCard
    {
        public MinerGPU(
            VideoCardDiscriminatingCharacteristics videoCardDiscriminatingCharacteristics,
            string deviceID, string bIOSVersion, bool isStrapped, double coreClock, double memClock, double coreVoltage, double powerLimit, ConcurrentObservableDictionary<Coin, HashRate> hashRatePerCoin) : base(
                videoCardDiscriminatingCharacteristics,

                                                                                                                                                                                        deviceID,
                                                                                                                                                                                        bIOSVersion,
                                                                                                                                                                                        isStrapped,
                                                                                                                                                                                        coreClock,
                                                                                                                                                                                        memClock,
                                                                                                                                                                                        coreVoltage,
                                                                                                                                                                                        powerLimit)
        {
            HashRatePerCoin = hashRatePerCoin;
        }

        public ConcurrentObservableDictionary<Coin, HashRate> HashRatePerCoin { get; set; }
    }

}
