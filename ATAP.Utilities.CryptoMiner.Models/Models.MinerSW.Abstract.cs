using System;
using System.Collections.Generic;
using Itenso.TimePeriod;
using ATAP.Utilities.ConcurrentObservableCollections;
using UnitsNet;
using ATAP.Utilities.ComputerInventory.Enumerations;

using ATAP.Utilities.CryptoCoin.Models;
using ATAP.Utilities.CryptoCoin.Enumerations;
using ATAP.Utilities.CryptoMiner.Models;
using ATAP.Utilities.CryptoMiner.Enumerations;
using ATAP.Utilities.ComputerInventory.Configuration;
using ATAP.Utilities.ComputerInventory.Configuration.Software;
using ATAP.Utilities.CryptoMiner.Interfaces;

using UnitsNet.Units;

namespace ATAP.Utilities.CryptoMiner.Models
{
  public static class MinerSWToMinerGPU
  {
    public static ConcurrentObservableDictionary<MinerGPU, MinerSWAbstract> minerSWToMinerGPU;

    static MinerSWToMinerGPU()
    {
      minerSWToMinerGPU = new ConcurrentObservableDictionary<MinerGPU, MinerSWAbstract>();
    }
  }

  public class MinerConfigSettings : IMinerConfigSettings
  {
    public MinerConfigSettings()
    {
    }

    public MinerConfigSettings(Coin[] coinsMined, int apiPort, int[][] coinVideoCardIntensity, FrequencyUnit coreClock, FrequencyUnit memoryClock, ElectricPotentialDcUnit memoryVoltage, int numVideoCardsToPowerUpInParallel, string[] poolPasswords, string[][] pools, string[] poolWallets, MinerSWE kind)
    {
      CoinsMined = coinsMined ?? throw new ArgumentNullException(nameof(coinsMined));
      ApiPort = apiPort;
      CoinVideoCardIntensity = coinVideoCardIntensity ?? throw new ArgumentNullException(nameof(coinVideoCardIntensity));
      CoreClock = coreClock;
      MemoryClock = memoryClock;
      MemoryVoltage = memoryVoltage;
      NumVideoCardsToPowerUpInParallel = numVideoCardsToPowerUpInParallel;
      PoolPasswords = poolPasswords ?? throw new ArgumentNullException(nameof(poolPasswords));
      Pools = pools ?? throw new ArgumentNullException(nameof(pools));
      PoolWallets = poolWallets ?? throw new ArgumentNullException(nameof(poolWallets));
      Kind = kind;
    }

    public Coin[] CoinsMined { get; set; }

    public int ApiPort { get; set; }
    public int[][] CoinVideoCardIntensity { get; set; }
    UnitsNet.Units.FrequencyUnit CoreClock { get; set; }
    public UnitsNet.Units.FrequencyUnit MemoryClock { get; set; }
    public UnitsNet.Units.ElectricPotentialDcUnit MemoryVoltage { get; set; }
    public int NumVideoCardsToPowerUpInParallel { get; set; }
    public string[] PoolPasswords { get; set; }
    public string[][] Pools { get; set; }
    public string[] PoolWallets { get; set; }

    public MinerSWE Kind { get; }
  }

  public abstract class MinerSWAbstract : ComputerSoftwareProgram, IMinerSWAbstract
  {
    public MinerSWAbstract(string processName, string processPath, string version, string processStartPath, bool hasConfigurationSettings, ConcurrentObservableDictionary<string, string> configurationSettings, string configFilePath, bool hasSTDOut, bool hasERROut, bool hasAPI, string aPIDiscoveryURL, bool hasLogFiles, string logFileFolder, string logFileFnPattern, Coin[] coinsMined, string[][] pools) : base(processName, processPath, version, processStartPath, hasConfigurationSettings, configurationSettings, configFilePath, hasSTDOut, hasERROut, hasAPI, aPIDiscoveryURL, hasLogFiles, logFileFolder, logFileFnPattern)
    {
      CoinsMined = coinsMined ?? throw new ArgumentNullException(nameof(coinsMined));
      Pools = pools ?? throw new ArgumentNullException(nameof(pools));
    }

    public Coin[] CoinsMined { get; }

    public string[][] Pools { get; set; }
  }

  public interface IMinerSWBuilder
  {
    MinerSWAbstract Build();
  }

  public abstract class MinerStatusAbstract : IMinerStatusAbstract
  {
    public MinerStatusAbstract()
    {
    }
    public MinerStatusAbstract(int iD, MinerStatusDetailsAbstract minerStatusDetails, string statusQueryError, string version, TimeBlock moment)
    {
      this.ID = iD;
      this.MinerStatusDetails = minerStatusDetails;
      this.StatusQueryError = statusQueryError;
      this.Version = version;
      this.Moment = moment;
    }

    public int ID { get; }

    public IMinerStatusDetailsAbstract MinerStatusDetails { get; }

    public ITimeBlock Moment { get; }

    public string StatusQueryError { get; }

    public string Version { get; }
  }



  public abstract class MinerStatusDetailsAbstract : IMinerStatusDetailsAbstract
  {
    public MinerStatusDetailsAbstract()
    {
    }

    public MinerStatusDetailsAbstract(ConcurrentObservableDictionary<int, Ratio> perGPUFanPct, ConcurrentObservableDictionary<int, ConcurrentObservableDictionary<Coin, double>> perGPUPerCoinHashRate, ConcurrentObservableDictionary<int, Power> perGPUPowerConsumption, ConcurrentObservableDictionary<int, Temperature> perGPUTemperature, string runningTime, ConcurrentObservableDictionary<Coin, double> totalPerCoinHashRate, ConcurrentObservableDictionary<Coin, int> totalPerCoinInvalidShares, ConcurrentObservableDictionary<Coin, int> totalPerCoinPoolSwitches, ConcurrentObservableDictionary<Coin, int> totalPerCoinRejectedShares, ConcurrentObservableDictionary<Coin, int> totalPerCoinShares, string version)
    {
      PerGPUFanPct = perGPUFanPct ?? throw new ArgumentNullException(nameof(perGPUFanPct));
      PerGPUPerCoinHashRate = perGPUPerCoinHashRate ?? throw new ArgumentNullException(nameof(perGPUPerCoinHashRate));
      PerGPUPowerConsumption = perGPUPowerConsumption ?? throw new ArgumentNullException(nameof(perGPUPowerConsumption));
      PerGPUTemperature = perGPUTemperature ?? throw new ArgumentNullException(nameof(perGPUTemperature));
      RunningTime = runningTime ?? throw new ArgumentNullException(nameof(runningTime));
      TotalPerCoinHashRate = totalPerCoinHashRate ?? throw new ArgumentNullException(nameof(totalPerCoinHashRate));
      TotalPerCoinInvalidShares = totalPerCoinInvalidShares ?? throw new ArgumentNullException(nameof(totalPerCoinInvalidShares));
      TotalPerCoinPoolSwitches = totalPerCoinPoolSwitches ?? throw new ArgumentNullException(nameof(totalPerCoinPoolSwitches));
      TotalPerCoinRejectedShares = totalPerCoinRejectedShares ?? throw new ArgumentNullException(nameof(totalPerCoinRejectedShares));
      TotalPerCoinShares = totalPerCoinShares ?? throw new ArgumentNullException(nameof(totalPerCoinShares));
      Version = version ?? throw new ArgumentNullException(nameof(version));
    }

    public ConcurrentObservableDictionary<int, UnitsNet.Ratio> PerGPUFanPct { get; }

    public ConcurrentObservableDictionary<int, ConcurrentObservableDictionary<Coin, double>> PerGPUPerCoinHashRate { get; }

    public ConcurrentObservableDictionary<int, UnitsNet.Power> PerGPUPowerConsumption { get; }

    public ConcurrentObservableDictionary<int, UnitsNet.Temperature> PerGPUTemperature { get; }

    public string RunningTime { get; }

    public ConcurrentObservableDictionary<Coin, double> TotalPerCoinHashRate { get; }

    public ConcurrentObservableDictionary<Coin, int> TotalPerCoinInvalidShares { get; }

    public ConcurrentObservableDictionary<Coin, int> TotalPerCoinPoolSwitches { get; }

    public ConcurrentObservableDictionary<Coin, int> TotalPerCoinRejectedShares { get; }

    public ConcurrentObservableDictionary<Coin, int> TotalPerCoinShares { get; }

    public string Version { get; }
  }


  public class TuneMinerGPUsResult : ITuneMinerGPUsResult, IEquatable<TuneMinerGPUsResult>
  {
    public TuneMinerGPUsResult()
    {
    }

    public TuneMinerGPUsResult(Frequency coreClock, ElectricPotentialDc coreVoltage, ConcurrentObservableDictionary<Coin, HashRate> hashRates, Frequency memClock, Power powerConsumption)
    {
      CoreClock = coreClock;
      CoreVoltage = coreVoltage;
      HashRates = hashRates ?? throw new ArgumentNullException(nameof(hashRates));
      MemClock = memClock;
      PowerConsumption = powerConsumption;
    }

    public UnitsNet.Frequency CoreClock { get; }

    public UnitsNet.ElectricPotentialDc CoreVoltage { get; }

    public ConcurrentObservableDictionary<Coin, HashRate> HashRates { get; }

    public UnitsNet.Frequency MemClock { get; }

    public UnitsNet.Power PowerConsumption { get; }

    public override bool Equals(object obj)
    {
      return Equals(obj as TuneMinerGPUsResult);
    }

    public bool Equals(TuneMinerGPUsResult other)
    {
      return other != null &&
             CoreClock.Equals(other.CoreClock) &&
             CoreVoltage.Equals(other.CoreVoltage) &&
             EqualityComparer<ConcurrentObservableDictionary<Coin, HashRate>>.Default.Equals(HashRates, other.HashRates) &&
             MemClock.Equals(other.MemClock) &&
             PowerConsumption.Equals(other.PowerConsumption);
    }

    public override int GetHashCode()
    {
      var hashCode = -1949465691;
      hashCode = hashCode * -1521134295 + CoreClock.GetHashCode();
      hashCode = hashCode * -1521134295 + CoreVoltage.GetHashCode();
      hashCode = hashCode * -1521134295 + EqualityComparer<ConcurrentObservableDictionary<Coin, HashRate>>.Default.GetHashCode(HashRates);
      hashCode = hashCode * -1521134295 + MemClock.GetHashCode();
      hashCode = hashCode * -1521134295 + PowerConsumption.GetHashCode();
      return hashCode;
    }

    public static bool operator ==(TuneMinerGPUsResult left, TuneMinerGPUsResult right)
    {
      return EqualityComparer<TuneMinerGPUsResult>.Default.Equals(left, right);
    }

    public static bool operator !=(TuneMinerGPUsResult left, TuneMinerGPUsResult right)
    {
      return !(left == right);
    }
  }
}
