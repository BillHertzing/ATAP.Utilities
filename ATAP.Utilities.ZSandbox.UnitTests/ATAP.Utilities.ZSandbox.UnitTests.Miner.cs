using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Threading.Tasks;
using ATAP.Utilities.ComputerInventory;
using ATAP.Utilities.CryptoCoin;
using Medallion.Shell;
using Swordfish.NET.Collections;
using UnitsNet;
using Xunit;

namespace ATAP.Utilities.ZSandbox.UnitTests
{
    public class AAMinerTest
    {
        /*
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
        public abstract class MinerStatus
        {
        readonly int iD;
        //readonly MinerSWE kind;
        readonly IMinerStatusDetails minerStatusDetails;
        //readonly TimeBlock moment;
        readonly string statusQueryError;
        readonly string version;
        
        public MinerStatus(string str)
        {
        }
        public MinerStatus(int iD,  MinerStatusDetails minerStatusDetails, string statusQueryError, string version)
        {
        this.iD = iD;
        this.minerStatusDetails = minerStatusDetails;
        this.statusQueryError = statusQueryError;
        this.version = version;
        
        }
        
        public int ID => iD;
        
        public IMinerStatusDetails MinerStatusDetails => minerStatusDetails;
        
        public string StatusQueryError => statusQueryError;
        
        public string Version => version;
        }
        
        public class ClaymoreMinerStatus : MinerStatus
        {
        //static string rEClaymoreMinerStatusReport = @"^{""id"":\s+(?<ID>\d+),\s+""result"":\s+\[(?<Details>.*?)\],\s+""error"":\s+(?<StatusQueryError>.*?)}$|^{""result"":\s+\[(?<Details>.*?)\],\s+""error"":\s+(?<StatusQueryError>.*?),\s+""id"":\s+(?<ID>\d+)}$|^{""id"":\s+(?<ID>\d+),\s+""error"":\s+(?<StatusQueryError>.*?),\s+""result"":\s+\[(?<Details>.*?)\]}$";
        static string rEClaymoreMinerStatusReport = @"^{""id"":\s+(?<ID>\d+),\s+""result"":\s+\[(?<Details>.*?)\],\s+""error"":\s+(?<StatusQueryError>.*?)}$|^{""result"":\s+\[(?<Details>.*?)\],\s+""error"":\s+(?<StatusQueryError>.*?),\s+""id"":\s+(?<ID>\d+)}$|^{""id"":\s+(?<ID>\d+),\s+""error"":\s+(?<StatusQueryError>.*?),\s+""result"":\s+\[(?<Details>.*?)\]}$|^^{""result"":\s+\[(?<Details>.*?)\],\s+""id"":\s+(?<ID>\d+),\s+""error"":\s+(?<StatusQueryError>.*?)}$";
        //static string rEClaymoreMinerStatusReport = @"^{(?=""id"":\s+(?<ID>\d+)(,|$)).*?(?=""error"":\s+(?<StatusQueryError>.*?)(,|$)).*?(?=(""result"":\s+\[(?<Details>.*?)\]).*).*?}$";
        
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
        
        
        public async Task<IMinerStatus> StatusFetchAsync()
        {
        // ToDo: Make this error message better
        //if (!(this.ComputerSoftwareProgram.HasAPI && this.ComputerSoftwareProgram.HasConfigurationSettings)) throw new NotImplementedException("This software does not implement StatusFetchAsync.");
        // ToDo: decide if localhost, or IPV4 127.0.0.1, or IPV6, is better here
        //var host = "localhost";
        var host = Dns.GetHostName();
        // ToDo: Look for a more elegant way to get the API port
        //this.ConfigurationSettings.Keys
        var port = 21200;
        //ToDo: Determine if the claymore miner SW API message should be stored in a text file
        var message = "{\"id\":0,\"jsonrpc\":\"2.0\",\"method\":\"miner_getstat1\"}";
        byte[] responsebuffer = new byte[Tcp.Tcp.defaultMaxResponseBufferSize];
        // ToDo figure out what to do about exceptions and policies  let exceptions bubble up?
        // If there is no process listening on the port, there will be an exception
        //ToDo add a cancellation token
        //ToDo:  better exception handling
        
        try
        {
        responsebuffer = await Tcp.Tcp.FetchAsync(host, port, message);
        }
        catch (Exception)
        {
        
        throw;
        }
        // remove trailing NULL characters from end of the string after converting the response buffer to ASCII
        string str = Encoding.ASCII.GetString(responsebuffer).TrimEnd('\0');
        return new ClaymoreMinerStatus(str);
        }
        */
        [Fact]
        public void AAtest()
        {
            bool fine = false;
            string processName = "EthDcrMiner64";
            string configFilePath = @"C:\ProgramData\CryptoCurrency\Ethereum\Claymore's Dual Ethereum+Decred_Siacoin_Lbry_Pascal AMD+NVIDIA GPU Miner v10.2\config.txt";
            bool hasAPI = true;
            bool hasConfigurationSettings = true; ;
            bool hasERROut = true;
            bool hasLogFiles = true;
            bool hasSTDOut = true;
            string logFileFnPattern = "\\d{10}_log.txt";
            string logFileFolder = @"C:\ProgramData\CryptoCurrency\Ethereum\Claymore's Dual Ethereum+Decred_Siacoin_Lbry_Pascal AMD+NVIDIA GPU Miner v10.2"; ;
            string processPath = @"C:\ProgramData\CryptoCurrency\Ethereum\Claymore's Dual Ethereum+Decred_Siacoin_Lbry_Pascal AMD+NVIDIA GPU Miner v10.2\EthDcrMiner64.exe";
            string processStartPath = @"C:\ProgramData\CryptoCurrency\Ethereum\Claymore's Dual Ethereum+Decred_Siacoin_Lbry_Pascal AMD+NVIDIA GPU Miner v10.2";
            string version = "10.2";
            Coin[] coinsMined = new Coin[2] { Coin.ETH, Coin.ZEC };
            ConcurrentObservableDictionary<string, string> configurationSettings = new ConcurrentObservableDictionary<string, string>()
            {
                {"mport", "21200"},
                {"epool","eth-us-east1.nanopool.org:9999" },
                {"epsw","x" },
                {"ewal","0xcdac8dea6d3ced686bacc9622fb7f92d29ed8874.ncat-m01/bill.hertzing@gmail.com" },
                {"esm","STRATUMTYPE" },
                {"mode","0" },
                {"dcoin","sc" },
                {"dpool","stratum+tcp://sia-us-east1.nanopool.org:7777" },
                {"dwal","72cb72ceb7b2b6b7a06c3393bdbd2311e180bb14cd629960d5a017d2dc816043be77abf79efe.ncat-m01/bill.hertzing@gmail.com" },
                {"dpsw","x" },
                {"dcri","4" },
                {"allpools","0" },
                {"ftime","0" },
                {"tt","85" },
                {"tstop", "90" },
                //{"di","0" },
                {"asm","1" },
                {"gser","2" },
                {"fanmin","50" },
                {"fanmax","100" },
                //{"benchmark", "170" },
                {"cclock", "0" },
                {"mclock", "0" },
            };

            VideoCardDiscriminatingCharacteristics localcardvcdc = VideoCardsKnown.TuningParameters.Keys.Where(x => (x.VideoCardMaker ==
    VideoCardMaker.ASUS
    && x.GPUMaker ==
    GPUMaker.NVIDEA))
                                                              .Single();
            ConcurrentObservableDictionary<Coin, HashRate> hashRatePerCoin = new ConcurrentObservableDictionary<Coin, HashRate>();
            MinerGPU minerGPU = new MinerGPU(localcardvcdc,
                                                "10DE 17C8 - 3842",
                                                "100.00001.02320.00",
                                                false,
                                                1140,
                                                1753,
                                                11.13,
                                                0.8,
                                                hashRatePerCoin);

            List<TuneMinerGPUsResult> tuneMinerGPUsResultList = new List<TuneMinerGPUsResult>();
            MinerGPU[] minerGPUsToTune = new MinerGPU[1] { minerGPU };

          
            // create the collection of MinerSWs to tune
            MinerSW[] minerSWsToTune = new MinerSW[1];
            ClaymoreETHDualMinerSW claymoreETHDualMinerSW = new ClaymoreETHDualMinerSW(processName,
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
    coinsMined);
            minerSWsToTune[0] = claymoreETHDualMinerSW;


            foreach (var msw in minerSWsToTune)
            {
                // Move to the directory where this software expects to start
                Directory.SetCurrentDirectory(msw.ProcessStartPath);
                foreach (var mg in minerGPUsToTune)
                {
                    // stop any running instances of this SW
                    Process.GetProcessesByName(msw.ProcessName).ToList().ForEach(x => x.Kill());
                    // Select the tuning strategy for this MinerSW and this VideoCard
                    var vcdc = mg.VideoCardDiscriminatingCharacteristics;
                    var vctp = VideoCardsKnown.TuningParameters[vcdc];
                    // Calculate the step for each parameter
                    int memoryClockStep = (vctp.MemoryClockMax - vctp.MemoryClockMin) / (fine ? 1 : 5);
                    int coreClockStep = (vctp.CoreClockMax - vctp.CoreClockMin) / (fine ? 1 : 5);
                    //double voltageStep = (vctp.VoltageMax - vctp.VoltageMin) / (fine ? 0.01 : 0.05);
                    // memoryClock Min, max, step
                    // CoreClock Min, max, step
                    // memoryVoltage min, max, step
                    int memoryClockTune;
                    int coreClockTune;
                    //double voltageTune = vctp.VoltageMin;
                    ConcurrentObservableDictionary<Coin, HashRate> hashRatePerCoinTune;
                    Power powerConsumptionTune;
                    // ToDo: initialize the structures that monitor for miner SW stopping, or Rig rebooting
                    //while (voltageTune <= vctp.VoltageMax)
                    //{
                    coreClockTune = vctp.CoreClockMin;
                    while (coreClockTune <= vctp.CoreClockMax)
                    {
                        msw.ConfigurationSettings["-cclock"] = coreClockTune.ToString();
                        memoryClockTune = vctp.MemoryClockMin;
                        while (memoryClockTune <= vctp.MemoryClockMax)
                        {
                            msw.ConfigurationSettings["-mclock"] = memoryClockTune.ToString();
                            // Stop the miner software
                            Process.GetProcessesByName(msw.ProcessName).ToList().ForEach(x => x.Kill());
                            // write the MinerSW Configuration to the miner's configuration file
                            //Func<KeyValuePair, string> cfgpair = (x) => $"-{x.Key} {x.Value}";
                            string s = string.Join(Environment.NewLine, msw.ConfigurationSettings.Select(x=> $"-{x.Key} {x.Value}"));
                            System.IO.File.WriteAllText(msw.ConfigFilePath, s);
                            // update the structures that monitor for miner SW stopping, or Rig rebooting

                            // Start the miner process
                            var cmd = Command.Run(processPath,new[] { ""}, options: o => o.DisposeOnExit(false));
                            //var outputLines = cmd.StandardOutput.GetLines().ToList();
                            //var errorText = cmd.StandardError.ReadToEnd();
                            // Wait a Delay for the card to settle
                            Task.Delay(new TimeSpan(0, 0, 3));
                            // Get the current HashRate and power consumption
                            //var minerStatus = await StatusFetchAsync();
                            // Dictionary<Coin, HashRate> hashRatesTune = new Dictionary<Coin, HashRate> { { Coin.ETH, new HashRate(1000.0, new TimeSpan(0, 0, 1)) } };
                            //PowerConsumption powerConsumptionTune = new PowerConsumption();
                            // Or Detect a minerSW stoppage or detect a rig reboot
                            // Stop the miner process
                            //cmd.Process.Close(); //todo: figure out DisposeOnExit(false)
                            Process.GetProcessesByName(msw.ProcessName).ToList().ForEach(x => x.Kill());


                            powerConsumptionTune = new Power(1);
                            hashRatePerCoinTune = new ConcurrentObservableDictionary<Coin, HashRate>();
                            foreach (var k in msw.CoinsMined)
                            {
                                hashRatePerCoinTune[k] = new HashRate(1,new TimeSpan(0,0,1));
                            }
                            // Record the results for this combination of msw,mvc,mClock,cClock,and mVoltage
                            tuneMinerGPUsResultList.Add(new TuneMinerGPUsResult(coreClockTune, memoryClockTune, vctp.VoltageDefault, hashRatePerCoinTune, powerConsumptionTune));
                            if (memoryClockTune != vctp.MemoryClockMax)
                            {
                                memoryClockTune += memoryClockStep;
                                memoryClockTune = memoryClockTune > vctp.MemoryClockMax ? vctp.MemoryClockMax : memoryClockTune;
                            } else { memoryClockTune += 1; }
                        }
                        if (coreClockTune != vctp.CoreClockMax)
                        {
                            coreClockTune += coreClockStep;
                            coreClockTune = coreClockTune > vctp.CoreClockMax ? vctp.CoreClockMax : coreClockTune;
                        }
                        else { coreClockTune += 1; }
                    }

                    //voltageTune += voltageStep;
                    //voltageTune = voltageTune > vctp.VoltageMax ? vctp.VoltageMax : voltageTune;
                    //}
                }
                // Best hashrate for this MinerSW, by order of coins mined
                //ConcurrentObservableDictionary<Coin, HashRate> bestHashRates
                //var bestMinerGPUResult = tuneMinerGPUsResultList.Max(x => x.HashRates[msw.CoinsMined[0]]);

            }
            //return tuneMinerGPUsResultList;

            Assert.Equal(1, 1);
        }
    }
}



