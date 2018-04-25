using System;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Threading;
using ATAP.Utilities.ComputerInventory;
using FluentAssertions;
using Newtonsoft.Json;
using Newtonsoft.Json.Converters;
using Swordfish.NET.Collections;
using Xunit;
using Xunit.Abstractions;

namespace ATAP.Utilities.CryptoCoin.UnitTests
{
    public class ClaymoreETHDualMinerFixture
    {
        public ClaymoreETHDualMinerProcess claymoreETHDualMinerProcess;
        public ClaymoreETHDualMinerSW claymoreETHDualMinerSW;
        public ComputerProcesses computerProcesses;

        public ClaymoreETHDualMinerFixture()
        {
            string processName = "claymore";
            string configFilePath = @"C:\ProgramData\CryptoCurrency\Ethereum\Claymore's Dual Ethereum+Decred_Siacoin_Lbry_Pascal AMD+NVIDIA GPU Miner v10.2";
            bool hasAPI = true;
            bool hasConfigurationSettings = true; ;
            bool hasERROut = true;
            bool hasLogFiles = true;
            bool hasSTDOut = true;
            string logFileFnPattern = "\\d{10}_log.txt";
            string logFileFolder = @"C:\ProgramData\CryptoCurrency\Ethereum\Claymore's Dual Ethereum+Decred_Siacoin_Lbry_Pascal AMD+NVIDIA GPU Miner v10.2"; ;
            //ComputerSW kind;
            string processPath = @"C:\ProgramData\CryptoCurrency\Ethereum\Claymore's Dual Ethereum+Decred_Siacoin_Lbry_Pascal AMD+NVIDIA GPU Miner v10.2\EthDcrMiner64.exe";
            string processStartPath = @"C:\ProgramData\CryptoCurrency\Ethereum\Claymore's Dual Ethereum+Decred_Siacoin_Lbry_Pascal AMD+NVIDIA GPU Miner v10.2";
            string version = "10.2";
            Coin[] coinsMined = new Coin[2] { Coin.ETH, Coin.ZEC };
            ConcurrentObservableDictionary<string, string> configurationSettings = new ConcurrentObservableDictionary<string, string>()
            {
                { "mport", "21200"},
                {"epool","eth-us-east1.nanopool.org:9999" },
                {"epsw","x" },
                {"ewal","0xcdac8dea6d3ced686bacc9622fb7f92d29ed8874.ncat-m01/bill.hertzing@gmail.com" },
                {"esm","STRATUMTYPE" },
                {"mode","0" },
                {"dcoin","sc" },
                {"dpool","stratum+tcp://sia-us-east1.nanopool.org:7777" },
                {"dwal","72cb72ceb7b2b6b7a06c3393bdbd2311e180bb14cd629960d5a017d2dc816043be77abf79efe.ncat-m01/bill.hertzing@gmail.com" },
                {"dpsw","x" },
                {"allpools","0" },
                {"tt","85" },
                {"asm","1" },
                {"gser","2" },
                {"fanmin","50" },
                {string.Empty,string.Empty},
            };

            claymoreETHDualMinerSW = new ClaymoreETHDualMinerSW(processName,
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
            claymoreETHDualMinerProcess = new ClaymoreETHDualMinerProcess(claymoreETHDualMinerSW);
            computerProcesses = new ComputerProcesses();

            JsonConvert.DefaultSettings = () => new JsonSerializerSettings
            {
                Converters =
                {
            new StringEnumConverter {
            CamelCaseText =
                    true
            }
            }
            };
        }
    }

    public class ClaymoreMinerProcessUnitTests001 : IClassFixture<ClaymoreETHDualMinerFixture>
    {
        readonly ITestOutputHelper output;
        protected ClaymoreETHDualMinerFixture _fixture;

        public ClaymoreMinerProcessUnitTests001(ITestOutputHelper output, ClaymoreETHDualMinerFixture fixture)
        {
            this.output = output;
            this._fixture = fixture;
        }

        [Fact]
        public async void ClaymoreStartStop()
        {
            var pid = _fixture.claymoreETHDualMinerProcess.Start();
            //var pid = _fixture.computerProcesses.Start(_fixture.claymoreETHDualMinerSW);
            // delay to settle
            Thread.Sleep(5);
            // get a status to prove it is running
            //ClaymoreETHDualMinerProcess claymoreETHDualMinerProcess =(ClaymoreETHDualMinerProcess) _fixture.computerProcesses.computerProcessDictionary[pid];
            // ToDo: Better handling of exceptions
            var status = await _fixture.claymoreETHDualMinerProcess.StatusFetchAsync();
            status.Should()
                .NotBeNull();
            // stop it
            _fixture.claymoreETHDualMinerProcess.Close();
            // get running processes and ensure the pid is no longer there
            var processes = Process.GetProcesses();
            bool none = processes.Where(p => p.Id == pid)
                            .Take(1)
                            .Count() ==
                0;
            none.Should()
                .Be(true);
        }
        [Fact]
        public async void ClaymoreMinerStatusDetails()
        {
            // cleanup ??
            Process.GetProcessesByName(_fixture.claymoreETHDualMinerProcess.ComputerSoftwareProgram.ProcessName).ToList().ForEach(x => x.Kill());
            ConcurrentObservableCollection<string> stdErrorLines = new ConcurrentObservableCollection<string>();
            ConcurrentObservableCollection<string> stdOutLines = new ConcurrentObservableCollection<string>();
            _fixture.claymoreETHDualMinerProcess.Cmd.RedirectStandardErrorTo(stdErrorLines);
            _fixture.claymoreETHDualMinerProcess.Cmd.RedirectTo(stdOutLines);
            var pid = _fixture.claymoreETHDualMinerProcess.Start();
            // delay to settle
            Thread.Sleep(5);
            // get a status to prove it is running
            // ToDo: Better handling of exceptions
            var status = await _fixture.claymoreETHDualMinerProcess.StatusFetchAsync();
            status.Should()
                .NotBeNull();
            // stop it
            _fixture.claymoreETHDualMinerProcess.Close();
            // get running processes and ensure the pid is no longer there
            var processes = Process.GetProcesses();
            bool none = processes.Where(p => p.Id == pid)
                            .Take(1)
                            .Count() ==
                0;
            none.Should()
                .Be(true);
        }
    }
}
