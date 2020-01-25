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
using ATAP.Utilities.ComputerInventory.Models;

namespace ATAP.Utilities.CryptoMiner.Models
{
    public static class MinerSWToMinerGPU
    {
        public static ConcurrentObservableDictionary<MinerGPU, MinerSW> minerSWToMinerGPU;

        static MinerSWToMinerGPU()
        {
            minerSWToMinerGPU = new ConcurrentObservableDictionary<MinerGPU, MinerSW>();
        }
    }

    public class MinerConfigSettings
    {
        Coin[] CoinsMined;
        MinerSWE kind;

        int ApiPort { get; set; }
        int[][] CoinVideoCardIntensity { get; set; }
        int CoreClock { get; set; }
        int MemoryClock { get; set; }
        int MemoryVoltage { get; set; }
        int NumVideoCardsToPowerUpInParallel { get; set; }
        string[] PoolPasswords { get; set; }
        string[][] Pools { get; set; }
        string[] PoolWallets { get; set; }

        public MinerSWE Kind { get => kind; }
    }

    public abstract class MinerSW : ComputerSoftwareProgram
    {
        readonly Coin[] coinsMined;
        readonly MinerSWE kind;

        public MinerSW(string processName, string processPath, string processStartPath, string version, bool hasConfigurationSettings, ConcurrentObservableDictionary<string, string> configurationSettings, string configFilePath, bool hasLogFiles, string logFileFolder, string logFileFnPattern, bool hasAPI, bool hasSTDOut, bool hasERROut, Coin[] coinsMined) : base(processName,
                                                                                                                                                                                                                                                                                                                                                                                            processPath,
                                                                                                                                                                                                                                                                                                                                                                                            processStartPath,
                                                                                                                                                                                                                                                                                                                                                                                            version,
                                                                                                                                                                                                                                                                                                                                                                                            hasConfigurationSettings,
                                                                                                                                                                                                                                                                                                                                                                                            configurationSettings,
                                                                                                                                                                                                                                                                                                                                                                                            configFilePath,
                                                                                                                                                                                                                                                                                                                                                                                            hasLogFiles,
                                                                                                                                                                                                                                                                                                                                                                                            logFileFolder,
                                                                                                                                                                                                                                                                                                                                                                                            logFileFnPattern,
                                                                                                                                                                                                                                                                                                                                                                                            hasAPI,
                                                                                                                                                                                                                                                                                                                                                                                            hasSTDOut,
                                                                                                                                                                                                                                                                                                                                                                                            hasERROut)
        {
            this.coinsMined = coinsMined;
        }

        public Coin[] CoinsMined => coinsMined;

        public MinerSWE Kind => kind;

        public string[][] Pools { get; set; }
    }

    public interface IMinerSWBuilder
    {
        MinerSW Build();
    }

    public interface IMinerStatus
    {
        int ID { get; }
        MinerSWE Kind { get; }
        IMinerStatusDetails MinerStatusDetails { get; }
        TimeBlock Moment { get; }
        string StatusQueryError { get; }
        string Version { get; }
    }

    public abstract class MinerStatus : IMinerStatus
    {
        readonly int iD;
        readonly MinerSWE kind;
        readonly IMinerStatusDetails minerStatusDetails;
        readonly TimeBlock moment;
        readonly string statusQueryError;
        readonly string version;

        public MinerStatus(string str)
        {
        }
        public MinerStatus(int iD, MinerSWE kind, MinerStatusDetails minerStatusDetails, string statusQueryError, string version, TimeBlock moment)
        {
            this.iD = iD;
            this.kind = kind;
            this.minerStatusDetails = minerStatusDetails;
            this.statusQueryError = statusQueryError;
            this.version = version;
            this.moment = moment;
        }

        public int ID => iD;

        public MinerSWE Kind => kind;

        public IMinerStatusDetails MinerStatusDetails => minerStatusDetails;

        public TimeBlock Moment => moment;

        public string StatusQueryError => statusQueryError;

        public string Version => version;
    }

    public interface IMinerStatusDetails
    {
        MinerSWE Kind { get; }
        ConcurrentObservableDictionary<int, double> PerGPUFanPct { get; }
        ConcurrentObservableDictionary<int, ConcurrentObservableDictionary<Coin, double>> PerGPUPerCoinHashRate { get; }
        ConcurrentObservableDictionary<int, Power> PerGPUPowerConsumption { get; }
        ConcurrentObservableDictionary<int, Temperature> PerGPUTemperature { get; }
        string RunningTime { get; }
        ConcurrentObservableDictionary<Coin, double> TotalPerCoinHashRate { get; }
        ConcurrentObservableDictionary<Coin, int> TotalPerCoinInvalidShares { get; }
        ConcurrentObservableDictionary<Coin, int> TotalPerCoinPoolSwitches { get; }
        ConcurrentObservableDictionary<Coin, int> TotalPerCoinRejectedShares { get; }
        ConcurrentObservableDictionary<Coin, int> TotalPerCoinShares { get; }
        string Version { get; }
    }

    public abstract class MinerStatusDetails : IMinerStatusDetails
    {
        readonly MinerSWE kind;
        readonly ConcurrentObservableDictionary<int, double> perGPUFanPct;
        readonly ConcurrentObservableDictionary<int, ConcurrentObservableDictionary<Coin, double>> perGPUPerCoinHashRate;
        readonly ConcurrentObservableDictionary<int, Power> perGPUPowerConsumption;
        readonly ConcurrentObservableDictionary<int, Temperature> perGPUTemperature;
        readonly string runningTime;
        readonly ConcurrentObservableDictionary<Coin, double> totalPerCoinHashRate;
        readonly ConcurrentObservableDictionary<Coin, int> totalPerCoinInvalidShares;
        readonly ConcurrentObservableDictionary<Coin, int> totalPerCoinPoolSwitches;
        readonly ConcurrentObservableDictionary<Coin, int> totalPerCoinRejectedShares;
        readonly ConcurrentObservableDictionary<Coin, int> totalPerCoinShares;

        readonly string version;

        public MinerStatusDetails(string str)
        {
        }

        public MinerStatusDetails(MinerSWE kind, string version, string runningTime, ConcurrentObservableDictionary<Coin, double> totalPerCoinHashRate, ConcurrentObservableDictionary<Coin, int> totalPerCoinShares, ConcurrentObservableDictionary<Coin, int> totalPerCoinRejectedShares, ConcurrentObservableDictionary<Coin, int> totalPerCoinInvalidShares, ConcurrentObservableDictionary<Coin, int> totalPerCoinPoolSwitches, ConcurrentObservableDictionary<int, ConcurrentObservableDictionary<Coin, double>> perGPUPerCoinHashRate, ConcurrentObservableDictionary<int, Temperature> perGPUTemperature, ConcurrentObservableDictionary<int, double> perGPUFanPct, ConcurrentObservableDictionary<int, Power> perGPUPowerConsumption)
        {
            this.version = version;
            this.runningTime = runningTime;
            this.totalPerCoinHashRate = totalPerCoinHashRate;
            this.totalPerCoinShares = totalPerCoinShares;
            this.totalPerCoinRejectedShares = totalPerCoinRejectedShares;
            this.totalPerCoinInvalidShares = totalPerCoinInvalidShares;
            this.totalPerCoinPoolSwitches = totalPerCoinPoolSwitches;
            this.perGPUPerCoinHashRate = perGPUPerCoinHashRate;
            this.perGPUTemperature = perGPUTemperature;
            this.perGPUFanPct = perGPUFanPct;
            this.perGPUPowerConsumption = perGPUPowerConsumption;
            this.kind = kind;
        }

        public MinerSWE Kind => kind;

        public ConcurrentObservableDictionary<int, double> PerGPUFanPct => perGPUFanPct;

        public ConcurrentObservableDictionary<int, ConcurrentObservableDictionary<Coin, double>> PerGPUPerCoinHashRate => perGPUPerCoinHashRate;

        public ConcurrentObservableDictionary<int, Power> PerGPUPowerConsumption => perGPUPowerConsumption;

        public ConcurrentObservableDictionary<int, Temperature> PerGPUTemperature => perGPUTemperature;

        public string RunningTime => runningTime;

        public ConcurrentObservableDictionary<Coin, double> TotalPerCoinHashRate => totalPerCoinHashRate;

        public ConcurrentObservableDictionary<Coin, int> TotalPerCoinInvalidShares => totalPerCoinInvalidShares;

        public ConcurrentObservableDictionary<Coin, int> TotalPerCoinPoolSwitches => totalPerCoinPoolSwitches;

        public ConcurrentObservableDictionary<Coin, int> TotalPerCoinRejectedShares => totalPerCoinRejectedShares;

        public ConcurrentObservableDictionary<Coin, int> TotalPerCoinShares => totalPerCoinShares;

        public string Version => version;
    }

  public interface ITuneMinerGPUsResult
  {
    double CoreClock { get; }
    double CoreVoltage { get; }
    ConcurrentObservableDictionary<Coin, HashRate> HashRates { get; }
    double MemClock { get; }
    Power PowerConsumption { get; }
  }
  public class TuneMinerGPUsResult : ITuneMinerGPUsResult
  {
    readonly double coreClock;
    readonly double coreVoltage;
    readonly ConcurrentObservableDictionary<Coin, HashRate> hashRates;
    readonly double memClock;
    readonly Power powerConsumption;

    public TuneMinerGPUsResult(double coreClock, double memClock, double coreVoltage, ConcurrentObservableDictionary<Coin, HashRate> hashRates, Power powerConsumption)
    {
      this.coreClock = coreClock;
      this.memClock = memClock;
      this.coreVoltage = coreVoltage;
      this.hashRates = hashRates;
      this.powerConsumption = powerConsumption;
    }

    public double CoreClock => coreClock;

    public double CoreVoltage => coreVoltage;

    public ConcurrentObservableDictionary<Coin, HashRate> HashRates => hashRates;

    public double MemClock => memClock;

    public Power PowerConsumption => powerConsumption;
  }
}
