using System;
using System.Text.RegularExpressions;
using ATAP.Utilities.ConcurrentObservableCollections;
using ATAP.Utilities.CryptoCoin.Enumerations;
using ATAP.Utilities.CryptoMiner.Enumerations;
using Itenso.TimePeriod;
using UnitsNet;
using ATAP.Utilities.CryptoMiner.Interfaces;

namespace ATAP.Utilities.CryptoMiner.Models
{
  public abstract class ClaymoreMinerSWAbstract : MinerSWAbstract
  {
    public ClaymoreMinerSWAbstract(string processName, string processPath, string version, string processStartPath, bool hasConfigurationSettings, ConcurrentObservableDictionary<string, string> configurationSettings, string configFilePath, bool hasSTDOut, bool hasERROut, bool hasAPI, string aPIDiscoveryURL, bool hasLogFiles, string logFileFolder, string logFileFnPattern, Coin[] coinsMined, string[][] pools) : base(
      processName,
      processPath,
      version,
      processStartPath,
      hasConfigurationSettings,
      configurationSettings,
      configFilePath,
      hasSTDOut,
      hasERROut,
      hasAPI,
      aPIDiscoveryURL,
      hasLogFiles,
      logFileFolder,
      logFileFnPattern,
      coinsMined,
      pools)
    {
    }

  }

  public class ClaymoreMinerStatus : MinerStatusAbstract
  {
    static string rEClaymoreMinerStatusReport = @"^{(?=.*""id"":\s+(?<ID>\d+)(?:,\s+|}))(?=.*""error"":\s+(?<error>.*?)(?:,\s+|}))(?=.*""result"":\s+\[(?<Details>.*?)](?:,\s+|}))";

    public ClaymoreMinerStatus(string str)
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
    public ClaymoreMinerStatus(int iD, ClaymoreMinerStatusDetails minerStatusDetails, string statusQueryError, string version, TimeBlock moment) :
        base(iD, minerStatusDetails, statusQueryError, version, moment)
    {
    }


  }

  public class ClaymoreMinerStatusDetails : MinerStatusDetailsAbstract
  {
    public ClaymoreMinerStatusDetails(string str)
    {

      string version;
      TimeBlock runningTime;
      ConcurrentObservableDictionary<Coin, double> totalPerCoinHashRate = new ConcurrentObservableDictionary<Coin, double>();
      ConcurrentObservableDictionary<Coin, int> totalPerCoinShares = new ConcurrentObservableDictionary<Coin, int>();
      ConcurrentObservableDictionary<Coin, int> totalPerCoinRejectedShares = new ConcurrentObservableDictionary<Coin, int>();
      ConcurrentObservableDictionary<Coin, int> totalPerCoinInvalidShares = new ConcurrentObservableDictionary<Coin, int>();
      ConcurrentObservableDictionary<Coin, int> totalPerCoinPoolSwitches = new ConcurrentObservableDictionary<Coin, int>();
      ConcurrentObservableDictionary<int, ConcurrentObservableDictionary<Coin, double>> perGPUPerCoinHashRate = new ConcurrentObservableDictionary<int, ConcurrentObservableDictionary<Coin, double>>();
      ConcurrentObservableDictionary<int, Temperature> perGPUTemperature = new ConcurrentObservableDictionary<int, Temperature>();
      ConcurrentObservableDictionary<int, Ratio> perGPUFanPct = new ConcurrentObservableDictionary<int, Ratio>();
      ConcurrentObservableDictionary<int, Power> perGPUPowerConsumption = new ConcurrentObservableDictionary<int, Power>();

      string rEClaymoreMinerStatusResultDetails = "^\"(?<Version>.*?),\\s+\"(?<RunningTime>.*?)\",\\s+\"(?<TotalETHHashRate>.*?);(?<TotalETHShares>.*?);(?<TotalETHRejectedShares>.*?)\",\\s+\"(?<PerGPUETHHashRate>.*?)\",\\s+\"(?<TotalSecondaryHashRate>.*?);(?<TotalSecondaryShares>.*?);(?<TotalSecondaryRejectedShares>.*?)\",\\s+\"(?<PerGPUSecondaryHashRate>.*?)\",\\s+\"(?<PerGPUTempFanPair>.*?)\",\\s+\"(?<CurrentMiningPools>.*?)\",\\s+\"(?<TotalETHInvalidShares>.*?);(?<TotalETHPoolSwitches>.*?);(?<TotalSecondaryInvalidShares>.*?);(?<TotalSecondaryPoolSwitches>.*?)\"";
      Regex RE1 = new Regex(rEClaymoreMinerStatusResultDetails, RegexOptions.IgnoreCase);
      MatchCollection matches = RE1.Matches(str);
      if (matches.Count == 0)
      {
        throw new ArgumentException($"Unable to match as a status response detailed: {str}");
      }

      foreach (Match match in matches)
      {
        GroupCollection groups = match.Groups;
        version = groups["Version"].Value ??
            throw new ArgumentNullException(nameof(version));
        if (groups["RunningTime"].Value is null) { throw new ArgumentNullException(nameof(runningTime)); }
        runningTime = new TimeBlock(DateTime.Parse(groups["RunningTime"].Value));
        /*

        // Version = new Regex(@"(\d|\.)+", RegexOptions.IgnoreCase).Matches;
        // Coin = groups["Version"].Value ?? throw new ArgumentNullException(nameof(Coin));
        RunningTime = groups["RunningTime"].Value ?? throw new ArgumentNullException(nameof(RunningTime));
        */
      }
    }

    public ClaymoreMinerStatusDetails(ConcurrentObservableDictionary<int, Ratio> perGPUFanPct, ConcurrentObservableDictionary<int, ConcurrentObservableDictionary<Coin, double>> perGPUPerCoinHashRate, ConcurrentObservableDictionary<int, Power> perGPUPowerConsumption, ConcurrentObservableDictionary<int, Temperature> perGPUTemperature, string runningTime, ConcurrentObservableDictionary<Coin, double> totalPerCoinHashRate, ConcurrentObservableDictionary<Coin, int> totalPerCoinInvalidShares, ConcurrentObservableDictionary<Coin, int> totalPerCoinPoolSwitches, ConcurrentObservableDictionary<Coin, int> totalPerCoinRejectedShares, ConcurrentObservableDictionary<Coin, int> totalPerCoinShares, string version) : base(perGPUFanPct, perGPUPerCoinHashRate, perGPUPowerConsumption, perGPUTemperature, runningTime, totalPerCoinHashRate, totalPerCoinInvalidShares, totalPerCoinPoolSwitches, totalPerCoinRejectedShares, totalPerCoinShares, version)
    {
    }
  }

  public class ClaymoreZECMinerSW : ClaymoreMinerSWAbstract
  {
    public ClaymoreZECMinerSW(string processName, string processPath, string version, string processStartPath, bool hasConfigurationSettings, ConcurrentObservableDictionary<string, string> configurationSettings, string configFilePath, bool hasSTDOut, bool hasERROut, bool hasAPI, string aPIDiscoveryURL, bool hasLogFiles, string logFileFolder, string logFileFnPattern, Coin[] coinsMined, string[][] pools) : base(processName, processPath, version, processStartPath, hasConfigurationSettings, configurationSettings, configFilePath, hasSTDOut, hasERROut, hasAPI, aPIDiscoveryURL, hasLogFiles, logFileFolder, logFileFnPattern, coinsMined, pools)
    {
    }
  }

  public class ClaymoreETHDualMinerSW : ClaymoreMinerSWAbstract
  {
    public ClaymoreETHDualMinerSW(string processName, string processPath, string version, string processStartPath, bool hasConfigurationSettings, ConcurrentObservableDictionary<string, string> configurationSettings, string configFilePath, bool hasSTDOut, bool hasERROut, bool hasAPI, string aPIDiscoveryURL, bool hasLogFiles, string logFileFolder, string logFileFnPattern, Coin[] coinsMined, string[][] pools) : base(processName, processPath, version, processStartPath, hasConfigurationSettings, configurationSettings, configFilePath, hasSTDOut, hasERROut, hasAPI, aPIDiscoveryURL, hasLogFiles, logFileFolder, logFileFnPattern, coinsMined, pools)
    {
    }

  }
}
