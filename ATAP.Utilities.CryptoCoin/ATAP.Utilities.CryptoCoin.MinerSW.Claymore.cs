using System;
using System.Text;
using System.Text.RegularExpressions;
using ATAP.Utilities.ComputerInventory;
using Itenso.TimePeriod;
using Swordfish.NET.Collections;
using ATAP.Utilities.Tcp;
using System.Threading.Tasks;
using UnitsNet;

namespace ATAP.Utilities.CryptoCoin
{
    public abstract class ClaymoreMinerSW : MinerSW
    {
        public ClaymoreMinerSW(string processName, string processPath, string processStartPath, string version, bool hasConfigurationSettings, ConcurrentObservableDictionary<string, string> configurationSettings, string configFilePath, bool hasLogFiles, string logFileFolder, string logFileFnPattern, bool hasAPI, bool hasSTDOut, bool hasERROut, Coin[] coinsMined) : base(processName,
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
                                                                                                                                                                                                                                                                                                                                                                                                    hasERROut,
                                                                                                                                                                                                                                                                                                                                                                                                    coinsMined)
        {
        }
    }

    public class ClaymoreMinerStatus : MinerStatus
    {
        static string rEClaymoreMinerStatusReport = @"^{(?=.*""id"":\s+(?<ID>\d+)(?:,\s+|}))(?=.*""error"":\s+(?<error>.*?)(?:,\s+|}))(?=.*""result"":\s+\[(?<Details>.*?)](?:,\s+|}))";

        public ClaymoreMinerStatus(string str) : base(str)
        {
            int iD;
            string statusQueryError;
            ClaymoreMinerStatusDetails details;
            Regex RE1 = new Regex(rEClaymoreMinerStatusReport, RegexOptions.IgnoreCase);
            MatchCollection matches = RE1.Matches(str);
            if(matches.Count != 1)
            {
                throw new ArgumentException($"Unable to match as a status response {str}");
            }

            foreach(Match match in matches)
            {
                GroupCollection groups = match.Groups;

                // ToDo tighten up security here, make sure it impossible that the "ID" value can be used as an attack vector
                if(!int.TryParse(groups["ID"].Value, out iD))
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
        public ClaymoreMinerStatus(int iD, ClaymoreMinerStatusDetails minerStatusDetails, string statusQueryError, string version, TimeBlock moment) :
            base(iD, MinerSWE.Claymore, minerStatusDetails, statusQueryError, version, moment)
        {
        }


    }

    public class ClaymoreMinerStatusDetails : MinerStatusDetails
    {
        public ClaymoreMinerStatusDetails(string str) : base(str)
        {

            string version;
            string runningTime;
            ConcurrentObservableDictionary<Coin, double> totalPerCoinHashRate = new ConcurrentObservableDictionary<Coin, double>();
            ConcurrentObservableDictionary<Coin, int> totalPerCoinShares = new ConcurrentObservableDictionary<Coin, int>();
            ConcurrentObservableDictionary<Coin, int> totalPerCoinRejectedShares = new ConcurrentObservableDictionary<Coin, int>();
            ConcurrentObservableDictionary<Coin, int> totalPerCoinInvalidShares = new ConcurrentObservableDictionary<Coin, int>();
            ConcurrentObservableDictionary<Coin, int> totalPerCoinPoolSwitches = new ConcurrentObservableDictionary<Coin, int>();
            ConcurrentObservableDictionary<int, ConcurrentObservableDictionary<Coin, double>> perGPUPerCoinHashRate = new ConcurrentObservableDictionary<int, ConcurrentObservableDictionary<Coin, double>>();
            ConcurrentObservableDictionary<int, Temperature> perGPUTemperature = new ConcurrentObservableDictionary<int, Temperature>();
            ConcurrentObservableDictionary<int, double> perGPUFanPct = new ConcurrentObservableDictionary<int, double>();
            ConcurrentObservableDictionary<int, Power> perGPUPowerConsumption = new ConcurrentObservableDictionary<int, Power>();

            string rEClaymoreMinerStatusResultDetails = "^\"(?<Version>.*?),\\s+\"(?<RunningTime>.*?)\",\\s+\"(?<TotalETHHashRate>.*?);(?<TotalETHShares>.*?);(?<TotalETHRejectedShares>.*?)\",\\s+\"(?<PerGPUETHHashRate>.*?)\",\\s+\"(?<TotalSecondaryHashRate>.*?);(?<TotalSecondaryShares>.*?);(?<TotalSecondaryRejectedShares>.*?)\",\\s+\"(?<PerGPUSecondaryHashRate>.*?)\",\\s+\"(?<PerGPUTempFanPair>.*?)\",\\s+\"(?<CurrentMiningPools>.*?)\",\\s+\"(?<TotalETHInvalidShares>.*?);(?<TotalETHPoolSwitches>.*?);(?<TotalSecondaryInvalidShares>.*?);(?<TotalSecondaryPoolSwitches>.*?)\"";
            Regex RE1 = new Regex(rEClaymoreMinerStatusResultDetails, RegexOptions.IgnoreCase);
            MatchCollection matches = RE1.Matches(str);
            if(matches.Count == 0)
            {
                throw new ArgumentException($"Unable to match as a status response detailed: {str}");
            }

            foreach(Match match in matches)
            {
                GroupCollection groups = match.Groups;
                version = groups["Version"].Value ??
                    throw new ArgumentNullException(nameof(version));
                runningTime = groups["RunningTime"].Value ??
                    throw new ArgumentNullException(nameof(runningTime));

                /*

                // Version = new Regex(@"(\d|\.)+", RegexOptions.IgnoreCase).Matches;
                // Coin = groups["Version"].Value ?? throw new ArgumentNullException(nameof(Coin));
                RunningTime = groups["RunningTime"].Value ?? throw new ArgumentNullException(nameof(RunningTime));
                */
            }
        }
        public ClaymoreMinerStatusDetails(string version, string runningTime, ConcurrentObservableDictionary<Coin, double> totalPerCoinHashRate, ConcurrentObservableDictionary<Coin, int> totalPerCoinShares, ConcurrentObservableDictionary<Coin, int> totalPerCoinRejectedShares, ConcurrentObservableDictionary<Coin, int> totalPerCoinInvalidShares, ConcurrentObservableDictionary<Coin, int> totalPerCoinPoolSwitches, ConcurrentObservableDictionary<int, ConcurrentObservableDictionary<Coin, double>> perGPUPerCoinHashRate, ConcurrentObservableDictionary<int, Temperature> perGPUTemperature, ConcurrentObservableDictionary<int, double> perGPUFanPct, ConcurrentObservableDictionary<int, Power> perGPUPowerConsumption)
            : base(MinerSWE.Claymore,
                  version, runningTime, totalPerCoinHashRate, totalPerCoinShares, totalPerCoinRejectedShares, totalPerCoinInvalidShares, totalPerCoinPoolSwitches, perGPUPerCoinHashRate, perGPUTemperature, perGPUFanPct, perGPUPowerConsumption)
                  
        {
        }
    }

    public class ClaymoreZECMinerSW : ClaymoreMinerSW
    {
        public ClaymoreZECMinerSW(string processName, string processPath, string processStartPath, string version, bool hasConfigurationSettings, ConcurrentObservableDictionary<string, string> configurationSettings, string configFilePath, bool hasLogFiles, string logFileFolder, string logFileFnPattern, bool hasAPI, bool hasSTDOut, bool hasERROut, Coin[] coinsMined) : base(processName, processPath, processStartPath, version, hasConfigurationSettings, configurationSettings, configFilePath, hasLogFiles, logFileFolder, logFileFnPattern, hasAPI, hasSTDOut, hasERROut, coinsMined)
        {
        }
    }

    public class ClaymoreETHDualMinerSW : ClaymoreMinerSW
    {
        public ClaymoreETHDualMinerSW(string processName, string processPath, string processStartPath, string version, bool hasConfigurationSettings, ConcurrentObservableDictionary<string, string> configurationSettings, string configFilePath, bool hasLogFiles, string logFileFolder, string logFileFnPattern, bool hasAPI, bool hasSTDOut, bool hasERROut, Coin[] coinsMined) : base(processName, processPath, processStartPath, version, hasConfigurationSettings, configurationSettings, configFilePath, hasLogFiles, logFileFolder, logFileFnPattern, hasAPI, hasSTDOut, hasERROut, coinsMined)
        {
        }
    }
}
