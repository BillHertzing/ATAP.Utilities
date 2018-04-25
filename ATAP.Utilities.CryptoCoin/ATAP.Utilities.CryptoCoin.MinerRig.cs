using ATAP.Utilities.ComputerInventory;
using Itenso.TimePeriod;
using Swordfish.NET.Collections;
using System;
using System.Collections.Generic;
using System.Text;
using UnitsNet;

namespace ATAP.Utilities.CryptoCoin
{
    public interface IRigConfig
    {
        TempAndFan CPUTempAndFan { get; set; }
        TimeBlock Moment { get; }
        ConcurrentObservableDictionary<int, MinerGPU> MinerGPUs { get; set; }
        ConcurrentObservableDictionary<(MinerSWE minerSWE, string version, Coin[] coins), MinerSW> MinerSWs { get; set; }
        PowerConsumption PowerConsumption { get; set; }
    }

    public class RigConfig : IRigConfig
    {
        TimeBlock moment;

        public RigConfig(TempAndFan cPUTempAndFan, PowerConsumption powerConsumption, ConcurrentObservableDictionary<(MinerSWE minerSWE, string version, Coin[] coins), MinerSW> minerSWs, ConcurrentObservableDictionary<int, MinerGPU> minerGPUs)
        {
            moment = new TimeBlock();
            CPUTempAndFan = cPUTempAndFan;
            PowerConsumption = powerConsumption;
            MinerSWs = minerSWs;
            MinerGPUs = minerGPUs;
        }

        //ToDo make CPUTempAndFan an observable
        public TempAndFan CPUTempAndFan { get; set; }
        public TimeBlock Moment { get => moment; }

        public ConcurrentObservableDictionary<int, MinerGPU> MinerGPUs { get; set; }
        public ConcurrentObservableDictionary<(MinerSWE minerSWE, string version, Coin[] coins), MinerSW> MinerSWs { get; set; }
        //ToDo make PowerConsumption an observable
        public PowerConsumption PowerConsumption { get; set; }
    }

    public interface IRigConfigBuilder
    {
        RigConfig Build();
    }

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
