using ATAP.Utilities.ComputerInventory;
//using ATAP.Utilities.ComputerInventory.Enumerations;
using ATAP.Utilities.ComputerInventory.Configuration;
using ATAP.Utilities.CryptoCoin.Models;
using ATAP.Utilities.CryptoCoin.Enumerations;
using ATAP.Utilities.CryptoMiner.Models;
using ATAP.Utilities.CryptoMiner.Enumerations;
using Itenso.TimePeriod;
using ATAP.Utilities.ConcurrentObservableCollections;
using System;
using System.Collections.Generic;
using System.Text;
using UnitsNet;
using ATAP.Utilities.ComputerInventory.Configuration.Hardware;
using ATAP.Utilities.CryptoMiner.Interfaces;
using ATAP.Utilities.ComputerInventory.Models.Hardware;

namespace ATAP.Utilities.CryptoCoin.Models
{

  public class RigConfigBuilder : IRigConfigBuilder
  {
    TempAndFan cPUTempAndFan;
    ConcurrentObservableDictionary<int, IMinerGPU> minerGPUs;
    ConcurrentObservableDictionary<(MinerSWE minerSWE, string version, Coin[] coins), IMinerSWAbstract> minerSWs;
    PowerConsumption powerConsumption;

    public IRigConfigBuilder AddMinerGPUs(ConcurrentObservableDictionary<int, IMinerGPU> minerGPUs)
    {
      this.minerGPUs = minerGPUs;
      return this;
    }
    public IRigConfigBuilder AddMinerSWs(ConcurrentObservableDictionary<(MinerSWE minerSWE, string version, Coin[] coins), IMinerSWAbstract> minerSWs)
    {
      this.minerSWs = minerSWs;
      return this;
    }
    public IRigConfigBuilder AddPowerConsumption(PowerConsumption powerConsumption)
    {
      this.powerConsumption = powerConsumption;
      return this;
    }
    public IRigConfigBuilder AddTempAndFan(TempAndFan cPUTempAndFan)
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
