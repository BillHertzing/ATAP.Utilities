using ATAP.Utilities.ComputerInventory;
using ATAP.Utilities.ComputerInventory.Enumerations;
using ATAP.Utilities.ComputerInventory.Models;
using ATAP.Utilities.CryptoCoin.Models;
using ATAP.Utilities.CryptoCoin.Enumerations;
using ATAP.Utilities.CryptoMiner.Models;
using ATAP.Utilities.CryptoMiner.Enumerations;
using Itenso.TimePeriod;
using Swordfish.NET.Collections;
using System;
using System.Collections.Generic;
using System.Text;
using UnitsNet;

namespace ATAP.Utilities.CryptoCoin.Extensions
{

    public class RigConfigBuilder : IRigConfigBuilder
    {
        TempAndFan cPUTempAndFan;
        ConcurrentObservableDictionary<int, MinerGPU> minerGPUs;
        ConcurrentObservableDictionary<(MinerSWE minerSWE, string version, Coin[] coins), MinerSW> minerSWs;
        PowerConsumption powerConsumption;

        public RigConfigBuilder AddMinerGPUs(ConcurrentObservableDictionary<int, MinerGPU> minerGPUs)
        {
            this.minerGPUs = minerGPUs;
            return this;
        }
        public RigConfigBuilder AddMinerSWs(ConcurrentObservableDictionary<(MinerSWE minerSWE, string version, Coin[] coins), MinerSW> minerSWs)
        {
            this.minerSWs = minerSWs;
            return this;
        }
        public RigConfigBuilder AddPowerConsumption(PowerConsumption powerConsumption)
        {
            this.powerConsumption = powerConsumption;
            return this;
        }
        public RigConfigBuilder AddTempAndFan(TempAndFan cPUTempAndFan)
        {
            this.cPUTempAndFan = cPUTempAndFan;
            return this;
        }

        public RigConfig Build()
        {
            return new RigConfig(cPUTempAndFan, powerConsumption, minerSWs, minerGPUs);
        }
        public static RigConfigBuilder CreateNew()
        {
            return new RigConfigBuilder();
        }
    }

}
