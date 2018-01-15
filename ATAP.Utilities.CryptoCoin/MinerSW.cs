using System;
using System.ComponentModel;
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
        public int ID {
            get {
                return iD;
            }

        }
        MinerSWE kind;
        public MinerSWE Kind {
            get {
                return kind;
            }
  
        }
        MinerStatusDetails minerStatusDetails;
        public MinerStatusDetails MinerStatusDetails {
            get {
                return minerStatusDetails;
            }
     
        }
        string statusQueryError;
        public string StatusQueryError {
            get {
                return statusQueryError;
            }
 
        }
        string version;
        public string Version {
            get {
                return version;
            }
 
        }
        public MinerStatus(int iD, MinerSWE kind, MinerStatusDetails minerStatusDetails, string statusQueryError, string version)
        {
            this.iD = iD;
            this.kind = kind;
            this.minerStatusDetails = minerStatusDetails;
            this.statusQueryError = statusQueryError;
            this.version = version;
        }
    }

    public class ClaymoreMinerStatus : MinerStatus
    {
        public ClaymoreMinerStatus(int iD,  MinerStatusDetails minerStatusDetails, string statusQueryError, string version) :
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
    }


public class ClaymoreMinerStatusDetails : MinerStatusDetails
{
        public ClaymoreMinerStatusDetails(int[][] detailedHashRatePerCoinPerGPU, int[] rejectedSharesPerCoin, string runningTime, TempAndFan[] tempAndFanPerGPU, int[] totalHashRatePerCoin, int[] totalSharesPerCoin, string version) 
            : base(detailedHashRatePerCoinPerGPU, MinerSWE.Claymore, rejectedSharesPerCoin, runningTime, tempAndFanPerGPU, totalHashRatePerCoin, totalSharesPerCoin, version)
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

/*
public class XMRMinerSWBuilder : IMinerSWBuilder
{
public String version;
public string[][] pools;
public string configFilePath;
public string processName;
public string processPath;
public string processStartPath;
public bool isRunning;

public AMinerSW Build()
{
return new ClaymoreMinerSW(version, pools, configFilePath, processName, processPath, processStartPath, isRunning);
}
public  ClaymoreMinerSWBuilder CreateNew()
{
return new ClaymoreMinerSWBuilder();
}
public  IClaymoreMinerSWBuilder AddVersion(string version)
{
this.version = version;
return this;
}
public IClaymoreMinerSWBuilder AddPools(string[][] Pools)
{
this.Pools = Pools;
return this;
}
public IClaymoreMinerSWBuilder AddDPools(string[] dPools)
{
this.dPools = dPools;
return this;
}
public IClaymoreMinerSWBuilder AddConfigFilePath(string configFilePath)
{
this.configFilePath = configFilePath;
return this;
}
public IClaymoreMinerSWBuilder AddProcessName(string processName)
{
this.processName = processName;
return this;
}
public IClaymoreMinerSWBuilder AddProcessPath(string processPath)
{
this.processPath = processPath;
return this;
}
public IClaymoreMinerSWBuilder AddProcessStartPath(string processStartPath)
{
this.processStartPath = processStartPath;
return this;
}
}

public abstract class ClaymoreMinerSW : AMinerSW
{
public ClaymoreMinerSW(
String version,
Coin[] coinsMined,
String[][] pools,
String configFilePath,
String logFileFolder,
String logFileFnPattern,
String processName,
String processPath,
String processStartPath,
bool isRunning) : base(version, coinsMined, pools, configFilePath, logFileFolder, logFileFnPattern, processName, processPath, processStartPath, isRunning)
{
Kind = MinerSWE.ClaymoreDualETHPlusOne;
}
}
*/
/*
public class ClaymoreMinerStatus : AMinerStatus<ClaymoreMinerStatus>
{
public ClaymoreMinerStatus(
String version,
int iD,
string statusQueryError,
MinerStatusDetails minerStatusDetails
)
{
Kind = MinerSW.Claymore;
Version = version;
ID = iD;
StatusQueryError = statusQueryError;
MinerStatusDetails = minerStatusDetails;
}
}

public interface IClaymoreMinerStatusBuilder
{
ClaymoreMinerStatus Build();
}

public class ClaymoreMinerStatusBuilder : IClaymoreMinerStatusBuilder
{
public String version;

public int iD;
public string statusQueryError;
public MinerStatusDetails minerStatusDetails;

public ClaymoreMinerStatus Build()
{
return new ClaymoreMinerStatus(version, iD, statusQueryError, minerStatusDetails);
}
public ClaymoreMinerStatusBuilder CreateNew()
{
return new ClaymoreMinerStatusBuilder();
}
public IClaymoreMinerStatusBuilder AddVersion(string version)
{
this.version = version;
return this;
}
public IClaymoreMinerStatusBuilder AddID(int iD)
{
this.iD = iD;
return this;
}
public IClaymoreMinerStatusBuilder AddStatusQueryError(string statusQueryError)
{
this.statusQueryError = statusQueryError;
return this;
}
public IClaymoreMinerStatusBuilder AddMinerStatusDetails(MinerStatusDetails minerStatusDetails)
{
this.minerStatusDetails = minerStatusDetails;
return this;
}
}
*/
/*
public class ClaymoreMinerStatusDetails : AMinerStatusDetails<ClaymoreMinerStatusDetails>
{
public ClaymoreMinerStatusDetails(
String version,
//ToDo make this a duration or timespan type
string runningTime,
int[] totalHashRatePerCoin,
int[] totalSharesPerCoin,
int[] rejectedSharesPerCoin,
int[][] detailedHashRatePerCoinPerGPU,
TempAndFan[] tempAndFanPerGPU
)
{
Kind = MinerSW.Claymore;
Version = version;
RunningTime = runningTime;
TotalHashRatePerCoin = totalHashRatePerCoin;
TotalSharesPerCoin = totalSharesPerCoin;
RejectedSharesPerCoin = rejectedSharesPerCoin;
DetailedHashRatePerCoinPerGPU = detailedHashRatePerCoinPerGPU;
TempAndFan = TempAndFanPerGPU;
}
}

public interface IClaymoreMinerStatusDetailsBuilder
{
ClaymoreMinerStatusDetails Build();
}

public class ClaymoreMinerStatusDetailsBuilder : IClaymoreMinerStatusDetailsBuilder
{
String version;
//ToDo make this a duration or timespan type
string runningTime;
int[] totalHashRatePerCoin;
int[] totalSharesPerCoin;
int[] rejectedSharesPerCoin;
int[][] detailedHashRatePerCoinPerGPU;
TempAndFan[] tempAndFanPerGPU;

public ClaymoreMinerStatusDetails Build()
{
return new ClaymoreMinerStatusDetails(version, runningTime, totalHashRatePerCoin, totalSharesPerCoin, rejectedSharesPerCoin, detailedHashRatePerCoinPerGPU, tempAndFanPerGPU);
}
public ClaymoreMinerStatusDetailsBuilder CreateNew()
{
return new ClaymoreMinerStatusDetailsBuilder();
}
public IClaymoreMinerStatusDetailsBuilder AddVersion(string version)
{
this.version = version;
return this;
}
public IClaymoreMinerStatusDetailsBuilder AddRunningTime(string runningTime)
{
this.runningTime = runningTime;
return this;
}
public IClaymoreMinerStatusDetailsBuilder AddTotalHashRatePerCoin(int[] totalHashRatePerCoin)
{
this.totalHashRatePerCoin = totalHashRatePerCoin;
return this;
}
public IClaymoreMinerStatusDetailsBuilder AddTotalSharesPerCoin(int[] totalSharesPerCoin)
{
this.totalSharesPerCoin = totalSharesPerCoin;
return this;
}
public IClaymoreMinerStatusDetailsBuilder AddRejectedSharesPerCoin(int[] rejectedSharesPerCoin)
{
this.rejectedSharesPerCoin = rejectedSharesPerCoin;
return this;
}
public IClaymoreMinerStatusDetailsBuilder AddDetailedHashRatePerCoinPerGPU(int[][] detailedHashRatePerCoinPerGPU)
{
this.detailedHashRatePerCoinPerGPU = detailedHashRatePerCoinPerGPU;
return this;
}
public IClaymoreMinerStatusDetailsBuilder AddTempAndFanPerGPU(TempAndFan[] tempAndFanPerGPU)
{
this.tempAndFanPerGPU = tempAndFanPerGPU;
return this;
}
}
public class ClaymoreMinerStatusReport
{
private static string rEClaymoreMinerStatusReport = @"^{""id"":\s+(?<ID>\d+),\s+""result"":\s+\[(?<Details>.*?)\],\s+""error"":\s+(?<StatusQueryError>.*?)}$|^{""result"":\s+\[(?<Details>.*?)\],\s+""error"":\s+(?<StatusQueryError>.*?),\s+""id"":\s+(?<ID>\d+)}$|^{""id"":\s+(?<ID>\d+),\s+""error"":\s+(?<StatusQueryError>.*?),\s+""result"":\s+\[(?<Details>.*?)\]}$";
public int ID { get; set; }
public string StatusQueryError { get; set; }
public ClaymoreMinerStatusResultDetails Details { get; set; }

public ClaymoreMinerStatusReport(string str)
{
Regex RE1 = new Regex(rEClaymoreMinerStatusReport, RegexOptions.IgnoreCase);
MatchCollection matches = RE1.Matches(str);
if (matches.Count != 1) throw new ArgumentException($"Unable to match as a status response {str}");
foreach (Match match in matches)
{
GroupCollection groups = match.Groups;
int iID;
// ToDo tighten up security here, make sure it impossible that the "ID" value can be used as an attack vector
if (int.TryParse(groups["ID"].Value, out iID)) { ID = iID; } else { throw new ArgumentException($"Unable to match as an integer {groups["ID"].Value}"); }
StatusQueryError = groups["StatusQueryError"].Value ?? throw new ArgumentNullException(nameof(StatusQueryError));
// Parse the details....
Details = new ClaymoreMinerStatusResultDetails(groups["Details"].Value ?? throw new ArgumentNullException(nameof(StatusQueryError)));
}
}
}

public class ClaymoreMinerStatusResultDetails
{
public string Miner { get; set; }
public string Coin { get; set; }
public string Version { get; set; }
public string RunningTime { get; set; }

public int[] TotalHashRatePerCoin { get; set; }
public int[] TotalSharesPerCoin { get; set; }
public int[] RejectedSharesPerCoin { get; set; }
public int[] DetailedHashRatePerCoinPerGPU { get; set; }
public TempAndFan[] TempAndFanPerGPU { get; set; }
string VersionCoin { get; set; }

public ClaymoreMinerStatusResultDetails(string str)
{
string rEClaymoreMinerStatusResultDetails = @"^(?<Version>.*?).*?,";

Miner = "Claymore";
Regex RE1 = new Regex(rEClaymoreMinerStatusResultDetails, RegexOptions.IgnoreCase);
MatchCollection matches = RE1.Matches(str);
if (matches.Count == 0) throw new ArgumentException($"Unable to match as a status response detailed: {str}");
foreach (Match match in matches)
{
GroupCollection groups = match.Groups;
var versionCoin = groups["VersionCoin"].Value ?? throw new ArgumentNullException(nameof(VersionCoin));
Version = versionCoin;

// Version = new Regex(@"(\d|\.)+", RegexOptions.IgnoreCase).Matches;
// Coin = groups["Version"].Value ?? throw new ArgumentNullException(nameof(Coin));
RunningTime = groups["RunningTime"].Value ?? throw new ArgumentNullException(nameof(RunningTime));
}
}
}
*/
}