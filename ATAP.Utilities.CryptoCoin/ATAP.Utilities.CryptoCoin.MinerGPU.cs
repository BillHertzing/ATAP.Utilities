using ATAP.Utilities.ComputerInventory;
using ATAP.Utilities.ComputerInventory.Models;
using Swordfish.NET.Collections;
using System;
using System.Collections.Generic;
using System.Text;

namespace ATAP.Utilities.CryptoCoin
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
