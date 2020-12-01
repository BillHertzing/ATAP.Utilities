//using ATAP.Utilities.ComputerInventory.Enumerations;
using ATAP.Utilities.CryptoCoin.Enumerations;
using ATAP.Utilities.CryptoMiner.Models;
using ATAP.Utilities.CryptoMiner.Enumerations;
using ATAP.Utilities.ConcurrentObservableCollections;
using ATAP.Utilities.CryptoMiner.Interfaces;
using ATAP.Utilities.ComputerInventory.Hardware;

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
