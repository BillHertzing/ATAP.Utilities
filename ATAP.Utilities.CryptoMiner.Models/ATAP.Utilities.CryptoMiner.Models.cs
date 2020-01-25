using System;
using Itenso.TimePeriod;
using ATAP.Utilities.ComputerInventory.Enumerations;
using ATAP.Utilities.ComputerInventory.Models;
using ATAP.Utilities.CryptoCoin.Enumerations;
using ATAP.Utilities.CryptoCoin.Models;
using ATAP.Utilities.CryptoMiner.Enumerations;
using ATAP.Utilities.ConcurrentObservableCollections;

namespace ATAP.Utilities.CryptoMiner.Models
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


}
