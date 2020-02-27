using System;
using Itenso.TimePeriod;
using ATAP.Utilities.ComputerInventory.Enumerations;
using ATAP.Utilities.ComputerInventory.Configuration;
using ATAP.Utilities.CryptoCoin.Enumerations;
using ATAP.Utilities.CryptoCoin.Models;
using ATAP.Utilities.CryptoMiner.Enumerations;
using ATAP.Utilities.ConcurrentObservableCollections;
using ATAP.Utilities.ComputerInventory.Interfaces.Hardware;
using ATAP.Utilities.CryptoMiner.Interfaces;

namespace ATAP.Utilities.CryptoMiner.Models
{

  public class RigConfig : IRigConfig
  {
    public RigConfig(ITempAndFan cPUTempAndFan, IPowerConsumption powerConsumption, ConcurrentObservableDictionary<(MinerSWE minerSWE, string version, Coin[] coins),IMinerSWAbstract> minerSWs, ConcurrentObservableDictionary<int, IMinerGPU> minerGPUs)
    {
      Moment = new TimeBlock();
      CPUTempAndFan = cPUTempAndFan;
      PowerConsumption = powerConsumption;
      MinerSWs = minerSWs;
      MinerGPUs = minerGPUs;
    }

    //ToDo make CPUTempAndFan an observable
    public ITempAndFan CPUTempAndFan { get; set; }
    public ITimeBlock Moment { get; }

    public ConcurrentObservableDictionary<int, IMinerGPU> MinerGPUs { get; set; }
    public ConcurrentObservableDictionary<(MinerSWE minerSWE, string version, Coin[] coins), IMinerSWAbstract> MinerSWs { get; set; }
    public IPowerConsumption PowerConsumption { get; set; }
  }


}
