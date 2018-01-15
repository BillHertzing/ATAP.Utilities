using System;
using System.ComponentModel;
using System.Text.RegularExpressions;
using Itenso.TimePeriod;
using Newtonsoft.Json;
using Newtonsoft.Json.Converters;
using Swordfish.NET.Collections;

namespace ATAP.Utilities.CryptoCoin
{
    // ToDo: continue to add miner SW to this list
    [JsonConverter(typeof(StringEnumConverter))]
    public enum MinerSWE
    {
        [Description("Claymore")]
        Claymore,
        [Description("ETHminer")]
        ETHMiner,
        [Description("GENOIL")]
        GENOIL,
        [Description("XMRStak ")]
        XMRStak,
        [Description("WolfsMiner")]
        WolfsMiner,
        [Description("MoneroSpelunker")]
        MoneroSpelunker
    }

    [JsonConverter(typeof(StringEnumConverter))]
    public enum GPUMfgr
    {
        [Description("AMD")]
        AMD,
        [Description("NVIDEA")]
        NVIDEA
    }

    // Add an enumeration for the known video card mfgrs

    public interface IRigConfig
    {
    }

    public class RigConfig
    {
        TimeBlock instantiationMoment;

        public RigConfig(TempAndFan cPUTempAndFan, PowerConsumption powerConsumption, ConcurrentObservableDictionary<(MinerSWE minerSWE, string version, Coin[] coins), MinerSW> minerSWs, ConcurrentObservableDictionary<int, GPUHW> gPUHWs)
        {
            instantiationMoment = new TimeBlock();
            CPUTempAndFan = cPUTempAndFan;
            PowerConsumption = powerConsumption;
            MinerSWs = minerSWs;
            GPUHWs = gPUHWs;
        }

        ConcurrentObservableDictionary<int, GPUHW> GPUHWs { get; set; }
        ConcurrentObservableDictionary<(MinerSWE minerSWE, string version, Coin[] coins), MinerSW> MinerSWs { get; set; }

        //ToDo make CPUTempAndFan an observable
        public TempAndFan CPUTempAndFan { get; set; }
        public TimeBlock InstantiationMoment { get => instantiationMoment; }
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
        ConcurrentObservableDictionary<int, GPUHW> gPUHWs;
        ConcurrentObservableDictionary<(MinerSWE minerSWE, string version, Coin[] coins), MinerSW> minerSWs;
        PowerConsumption powerConsumption;

        public IRigConfigBuilder AddGPUHWs(ConcurrentObservableDictionary<int, GPUHW> gPUHWs)
        {
            this.gPUHWs = gPUHWs;
            return this;
        }
        public IRigConfigBuilder AddMinerSWs(ConcurrentObservableDictionary<(MinerSWE minerSWE, string version, Coin[] coins), MinerSW> minerSWs)
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
            return new RigConfig(cPUTempAndFan, powerConsumption, minerSWs, gPUHWs);
        }
        public static RigConfigBuilder CreateNew()
        {
            return new RigConfigBuilder();
        }
    }

    public abstract class MinerSW
    {
        Coin[] coinsMined;
        MinerSWE kind;
        string processName;
        string processPath;
        string processStartPath;
        string version;

        public MinerSW(
            MinerSWE kind,
         string version,
         Coin[] coinsMined,
         string[][] pools,
         string configFilePath,
         string logFileFolder,
         string logFileFnPattern,
         string processName,
         string processPath,
         string processStartPath,
            bool isRunning)
        {
            this.kind = kind;
            this.version = version;
            this.coinsMined = CoinsMined;
            Pools = pools;
            ConfigFilePath = configFilePath;
            LogFileFolder = logFileFolder;
            LogFileFnPattern = logFileFnPattern;
            this.processName = processName;
            this.processPath = processPath;
            this.processStartPath = processStartPath;
            IsRunning = isRunning;
        }

        public Coin[] CoinsMined { get => coinsMined; }
        public string ConfigFilePath { get; set; }
        public bool IsRunning { get; set; }
        public MinerSWE Kind { get => kind; }
        public string LogFileFnPattern { get; set; }
        public string LogFileFolder { get; set; }
        public string[][] Pools { get; set; }
        public string ProcessName { get => processName; }
        public string ProcessPath { get => processPath; }
        public string ProcessStartPath { get => processStartPath; }
        public string Version { get => version; }
    }

    public interface IMinerSWBuilder
    {
        MinerSW Build();
    }

    public abstract class MinerStatus
    {
        int iD;
        MinerSWE kind;
        MinerStatusDetails minerStatusDetails;
        string statusQueryError;
        string version;

        public MinerStatus(string str)
        {
        }
        public MinerStatus(int iD, MinerSWE kind, MinerStatusDetails minerStatusDetails, string statusQueryError, string version)
        {
            this.iD = iD;
            this.kind = kind;
            this.minerStatusDetails = minerStatusDetails;
            this.statusQueryError = statusQueryError;
            this.version = version;
        }

        public int ID {
            get { return iD; }
        }
        public MinerSWE Kind {
            get { return kind; }
        }
        public MinerStatusDetails MinerStatusDetails {
            get { return minerStatusDetails; }
        }
        public string StatusQueryError {
            get { return statusQueryError; }
        }
        public string Version {
            get { return version; }
        }
    }

    public class ClaymoreMinerStatus : MinerStatus
    {
        static string rEClaymoreMinerStatusReport = @"^{""id"":\s+(?<ID>\d+),\s+""result"":\s+\[(?<Details>.*?)\],\s+""error"":\s+(?<StatusQueryError>.*?)}$|^{""result"":\s+\[(?<Details>.*?)\],\s+""error"":\s+(?<StatusQueryError>.*?),\s+""id"":\s+(?<ID>\d+)}$|^{""id"":\s+(?<ID>\d+),\s+""error"":\s+(?<StatusQueryError>.*?),\s+""result"":\s+\[(?<Details>.*?)\]}$";

        public ClaymoreMinerStatus(string str) : base(str)
        {
            int iD;
            string statusQueryError;
            ClaymoreMinerStatusDetails details;
            Regex RE1 = new Regex(rEClaymoreMinerStatusReport, RegexOptions.IgnoreCase);
            MatchCollection matches = RE1.Matches(str);
            if (matches.Count != 1)
            {
                throw new ArgumentException($"Unable to match as a status response {str}");
            }

            foreach (Match match in matches)
            {
                GroupCollection groups = match.Groups;

                // ToDo tighten up security here, make sure it impossible that the "ID" value can be used as an attack vector
                if (!int.TryParse(groups["ID"].Value, out iD))
                {
                    throw new ArgumentException($"Unable to match as an integer {groups["ID"].Value}");
                }

                statusQueryError = groups["StatusQueryError"].Value ??
                    throw new ArgumentNullException(nameof(statusQueryError));
                // Parse the details....
                details = new ClaymoreMinerStatusDetails(groups["Details"].Value ??
                    throw new ArgumentNullException(nameof(details)));
            }
        }
        public ClaymoreMinerStatus(int iD, MinerStatusDetails minerStatusDetails, string statusQueryError, string version) :
            base(iD, MinerSWE.Claymore, minerStatusDetails, statusQueryError, version)
        {
        }
    }

    public abstract class MinerStatusDetails
    {
        int[][] detailedHashRatePerCoinPerGPU;
        MinerSWE kind;
        int[] rejectedSharesPerCoin;
        string runningTime;
        TempAndFan[] tempAndFanPerGPU;

        int[] totalHashRatePerCoin;
        int[] totalSharesPerCoin;
        string version;

        public MinerStatusDetails(string str)
        {
        }

        public MinerStatusDetails(int[][] detailedHashRatePerCoinPerGPU, MinerSWE kind, int[] rejectedSharesPerCoin, string runningTime, TempAndFan[] tempAndFanPerGPU, int[] totalHashRatePerCoin, int[] totalSharesPerCoin, string version)
        {
            this.detailedHashRatePerCoinPerGPU = detailedHashRatePerCoinPerGPU;
            this.kind = kind;
            this.rejectedSharesPerCoin = rejectedSharesPerCoin;
            this.runningTime = runningTime;
            this.tempAndFanPerGPU = tempAndFanPerGPU;
            this.totalHashRatePerCoin = totalHashRatePerCoin;
            this.totalSharesPerCoin = totalSharesPerCoin;
            this.version = version;
        }

        public int[][] DetailedHashRatePerCoinPerGPU {
            get => detailedHashRatePerCoinPerGPU;
        }
        public MinerSWE Kind { get => kind; }
        public int[] RejectedSharesPerCoin {
            get => rejectedSharesPerCoin;
        }
        public string RunningTime {
            get => runningTime;
        }
        public TempAndFan[] TempAndFanPerGPU {
            get => tempAndFanPerGPU;
        }
        public int[] TotalHashRatePerCoin {
            get => totalHashRatePerCoin;
        }
        public int[] TotalSharesPerCoin {
            get => totalSharesPerCoin;
        }
        public string Version {
            get => version;
        }
    }

    public class ClaymoreMinerStatusDetails : MinerStatusDetails
    {
        public ClaymoreMinerStatusDetails(string str) : base(str)
        {
            string rEClaymoreMinerStatusResultDetails = @"^(?<Version>.*?).*?,";
            Regex RE1 = new Regex(rEClaymoreMinerStatusResultDetails, RegexOptions.IgnoreCase);
            MatchCollection matches = RE1.Matches(str);
            if (matches.Count == 0)
            {
                throw new ArgumentException($"Unable to match as a status response detailed: {str}");
            }

            foreach (Match match in matches)
            {
                GroupCollection groups = match.Groups;
                /*
                var versionCoin = groups["VersionCoin"].Value ?? throw new ArgumentNullException(nameof(VersionCoin));
                Version = versionCoin;

                // Version = new Regex(@"(\d|\.)+", RegexOptions.IgnoreCase).Matches;
                // Coin = groups["Version"].Value ?? throw new ArgumentNullException(nameof(Coin));
                RunningTime = groups["RunningTime"].Value ?? throw new ArgumentNullException(nameof(RunningTime));
                */
            }
        }
        public ClaymoreMinerStatusDetails(int[][] detailedHashRatePerCoinPerGPU, int[] rejectedSharesPerCoin, string runningTime, TempAndFan[] tempAndFanPerGPU, int[] totalHashRatePerCoin, int[] totalSharesPerCoin, string version)
            : base(detailedHashRatePerCoinPerGPU,
                   MinerSWE.Claymore,
                   rejectedSharesPerCoin,
                   runningTime,
                   tempAndFanPerGPU,
                   totalHashRatePerCoin,
                   totalSharesPerCoin,
                   version)
        {
        }
    }

    public abstract class GPUHW
    {
        ConcurrentObservableDictionary<string, double> bindableDoubles;
        string bIOSVersion;
        string cardName;
        string deviceID;
        GPUMfgr gPUMfgr;
        bool isStrapped;
        string subVendor;

        public GPUHW(

         GPUMfgr gPUMfgr,
         string subVendor,
         string cardName,
         string deviceID,
         string bIOSVersion,
         bool isStrapped,
         double coreClock,
         double memClock,
         double coreVoltage,
         double powerLimit,
         ConcurrentObservableDictionary<Coin, HashRate> hashRatePerCoin,
         PowerConsumption powerConsumption,
         TempAndFan tempAndFan,
        bool isRunning
            )
        {
            this.gPUMfgr = gPUMfgr;
            this.subVendor = subVendor;
            this.cardName = cardName;
            this.deviceID = deviceID;
            this.bIOSVersion = bIOSVersion;
            this.isStrapped = isStrapped;
            CoreClock = coreClock;
            MemClock = memClock;
            CoreVoltage = coreVoltage;
            PowerLimit = powerLimit;
            HashRatePerCoin = hashRatePerCoin;
            PowerConsumption = powerConsumption;
            TempAndFan = tempAndFan;
            IsRunning = isRunning;
            bindableDoubles = new ConcurrentObservableDictionary<string, double>() {
                {"CoreClock", coreClock },
                {"MemClock", memClock },
                {"CoreVoltage", coreVoltage },
                {"PowerLimit", powerLimit },
            };
        }

        ConcurrentObservableDictionary<string, double> BindableDoubles { get => bindableDoubles; }

        public string BIOSVersion { get => bIOSVersion; }
        public string CardName { get => cardName; }
        public double CoreClock { get; set; }
        public double CoreVoltage { get; set; }
        public string DeviceID { get => deviceID; }
        public GPUMfgr GPUMfgr { get => gPUMfgr; }
        public ConcurrentObservableDictionary<Coin, HashRate> HashRatePerCoin { get; set; }
        public bool IsRunning { get; set; }
        public bool IsStrapped { get => isStrapped; }
        public double MemClock { get; set; }
        public PowerConsumption PowerConsumption { get; set; }
        public double PowerLimit { get; set; }
        public string SubVendor { get => subVendor; }
        public TempAndFan TempAndFan { get; set; }
    }

    public abstract class ClaymoreMinerSW : MinerSW
    {
        public ClaymoreMinerSW(
         string version,
         Coin[] coinsMined,
         string[][] pools,
         string configFilePath,
         string logFileFolder,
         string logFileFnPattern,
         string processName,
         string processPath,
         string processStartPath,
            bool isRunning) : base(MinerSWE.Claymore,
                                   version,
                                   coinsMined,
                                   pools,
                                   configFilePath,
                                   logFileFolder,
                                   logFileFnPattern,
                                   processName,
                                   processPath,
                                   processStartPath,
                                   isRunning)
        {
        }
    }

    public class ClaymoreZECMinerSW : ClaymoreMinerSW
    {
        public ClaymoreZECMinerSW(
         string version,
         string[][] pools,
         string configFilePath,
         string logFileFolder,
         string logFileFnPattern,
         string processName,
         string processPath,
         string processStartPath,
            bool isRunning) : base(version,
                                   new Coin[1] { Coin.ZEC },
                                   pools,
                                   configFilePath,
                                   logFileFolder,
                                   logFileFnPattern,
                                   processName,
                                   processPath,
                                   processStartPath,
                                   isRunning)
        {
        }
    }

    public class ClaymoreETHDualMinerSW : ClaymoreMinerSW
    {
        public ClaymoreETHDualMinerSW(
         string version,
         Coin secondCoinMined,
         string[][] pools,
         string configFilePath,
         string logFileFolder,
         string logFileFnPattern,
         string processName,
         string processPath,
         string processStartPath,
            bool isRunning) : base(version,
                                   new Coin[2] { Coin.ETH, secondCoinMined },
                                   pools,
                                   configFilePath,
                                   logFileFolder,
                                   logFileFnPattern,
                                   processName,
                                   processPath,
                                   processStartPath,
                                   isRunning)
        {
        }
    }

    public class AMDGPUHW : GPUHW
    {
        public AMDGPUHW(
                  string subVendor,
         string cardName,
         string deviceID,
         string bIOSVersion,

         bool isStrapped,
                  double coreClock,
         double memClock,
         double coreVoltage,
         double powerLimit,
    ConcurrentObservableDictionary<Coin, HashRate> hashRatePerCoin,
         PowerConsumption powerConsumption,
         TempAndFan tempAndFan,
        bool isRunning
            ) : base(GPUMfgr.AMD,
                     subVendor,
                     cardName,
                     deviceID,
                     bIOSVersion,
                     isStrapped,
                     coreClock,
                     memClock,
                     coreVoltage,
                     powerLimit,
                     hashRatePerCoin,
                     powerConsumption,
                     tempAndFan,
                     isRunning)
        {
        }
    }

}