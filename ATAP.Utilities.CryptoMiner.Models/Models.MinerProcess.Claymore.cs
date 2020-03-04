using ATAP.Utilities.ComputerInventory.Configuration;
using ATAP.Utilities.CryptoCoin.Enumerations;
using ATAP.Utilities.CryptoCoin.Models;
using ATAP.Utilities.ConcurrentObservableCollections;
using System;
using System.Collections.Generic;
using System.Net;
using System.Text;
using System.Threading.Tasks;
using UnitsNet;
using ATAP.Utilities.ComputerInventory.Extensions;
using Medallion.Shell;
using ATAP.Utilities.ComputerInventory.Configuration.Hardware;
using ATAP.Utilities.CryptoMiner.Interfaces;
using System.Linq;
using ATAP.Utilities.ComputerInventory.Models.Hardware;

namespace ATAP.Utilities.CryptoMiner.Models
{

  public abstract class ClaymoreMinerProcessAbstract : MinerProcessAbstract
  {

    public ClaymoreMinerProcessAbstract(MinerSWAbstract computerSoftwareProgram, Command command, params object[] arguments) : base(computerSoftwareProgram, command, arguments)
    {
    }

    public override async Task<IMinerStatusAbstract> StatusFetchAsync()
    {
      //var DUalStr = "{\"id\": 0, \"result\": [\"10.2 - ETH\", \"4258\", \"50033;1249;0\", \"24583;25450\", \"1501011;2571;0\", \"737502;763509\", \"68;100;81;100\", \"eth-us-east1.nanopool.org:9999;sia-us-east1.nanopool.org:7777\", \"0;2;0;2\"], \"error\": null}";
      //var msorigianlZEC = "{\"id\": 0, \"error\": null, \"result\": [\"12.6 - ZEC\", \"1676\", \"352; 1300; 4\", \"175; 177\", \"0; 0; 0\", \"off; off\", \"81; 100\", \"zec - us - east1.nanopool.org:6633\", \"0; 2; 0; 0\"]}";
      //var ms = "{\"id\": 0, \"error\": null, \"result\": [\"12.6 - ZEC\", \"1676\", \"352; 1300; 4\", \"175; 177\", \"0; 0; 0\", \"off; off\", \"81; 100\", \"zec - us - east1.nanopool.org:6633\", \"0; 2; 0; 0\"]}";
      // ToDo: Make this error message better
      if (!(this.ComputerSoftwareProgram.HasAPI && this.ComputerSoftwareProgram.HasConfigurationSettings))
      {
        throw new NotImplementedException("This software does not implement StatusFetchAsync.");
      }
      // ToDo: decide if localhost, or IPV4 127.0.0.1, or IPV6, is better here
      //var host = "localhost";
      var host = Dns.GetHostName();
      // ToDo: Look for a more elegant way to get the API port
      //this.ConfigurationSettings.Keys
      var port = 21200;
      //ToDo: Determine if the claymore miner SW API message should be stored in a text file
      var message = "{\"id\":0,\"jsonrpc\":\"2.0\",\"method\":\"miner_getstat1\"}";
      byte[] responsebuffer; // = new byte[Tcp.Tcp.defaultMaxResponseBufferSize];
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

    public async override Task<List<ITuneMinerGPUsResult>> TuneMinersAsync()
    {
      bool fine = true;
      //ToDo asking for highest HashRate or most efficient HashRate?
      // create the collection of GPUs to tune
      MinerGPU[] minerGPUsToTune = new MinerGPU[1];
      // create the collection of MinerSWs to tune
      MinerSWAbstract[] minerSWsToTune = new MinerSWAbstract[1];
      // create the results
      var tuneMinerGPUsResultList = new List<TuneMinerGPUsResult>();
      foreach (var msw in minerSWsToTune)
      {
        foreach (var mg in minerGPUsToTune)
        {
          // Select the tuning strategy for this MinerSW and this VideoCard
          var vcdc = mg.VideoCardSignil;
          VideoCardTuningParameters vctp = new VideoCardTuningParameters(); ; //ATAP.Utilities.ComputerInventory.Configuration.DefaultConfiguration.TuningParameters[vcdc];
          // Calculate the step for each parameter
          UnitsNet.Frequency memoryClockStep = (vctp.MemoryClockMax - vctp.MemoryClockMin) / (fine ? 1 : 5);
          UnitsNet.Frequency coreClockStep = (vctp.CoreClockMax - vctp.CoreClockMin) / (fine ? 1 : 5);
          UnitsNet.ElectricPotentialDc voltageStep = (vctp.VoltageMax - vctp.VoltageMin) / (fine ? 0.01 : 0.05);
          // memoryClock Min, max, step
          // CoreClock Min, max, step
          // memoryVoltage min, max, step
          UnitsNet.Frequency memoryClockTune = vctp.MemoryClockMin;
          UnitsNet.Frequency coreClockTune = vctp.CoreClockMin;
          UnitsNet.ElectricPotentialDc voltageTune = vctp.VoltageMin;
          // initialize the structures that monitor for miner SW stopping, or Rig rebooting
          while (voltageTune <= vctp.VoltageMax)
          {
            while (coreClockTune <= vctp.CoreClockMax)
            {
              while (memoryClockTune <= vctp.MemoryClockMax)
              {
                // create the tuning configuration settings for this MinerSW and this VideoCard
                //MinerGPUTuningconfig minerGPUTuningconfig;

                // Stop the miner software
                this.CloseMainWindow();
                // update the MinerSW configuration
                //msw.SetConfig(minerGPUTuningconfig);
                // write the MinerSW Configuration to the miner's configuration file
                // msw.SaveConfig
                // update the structures that monitor for miner SW stopping, or Rig rebooting
                // Start the miner MinerSW
                //msw.Start();
                // Wait a Delay for the card to settle
                // Get the current HashRate and power consumption
                var minerStatus = await this.StatusFetchAsync();
                ConcurrentObservableDictionary<Coin, HashRate> hashRatesTune = new ConcurrentObservableDictionary<Coin, HashRate> { { Coin.ETH, new HashRate(1000.0, new TimeSpan(0, 0, 1)) } };
                Power powerConsumptionTune = new Power();
                // Or Detect a minerSW stoppage or detect a rig reboot
                // Record the results for this combination of msw,mvc,mClock,cClock,and mVoltage
                tuneMinerGPUsResultList.Add(new TuneMinerGPUsResult(coreClockTune, voltageTune, hashRatesTune, memoryClockTune,  powerConsumptionTune));
                memoryClockTune += memoryClockStep;
                memoryClockTune = memoryClockTune > vctp.MemoryClockMax ?
                    vctp.MemoryClockMax :
                    memoryClockTune;
              }
              coreClockTune += coreClockStep;
              coreClockTune = coreClockTune > vctp.CoreClockMax ? vctp.CoreClockMax : coreClockTune;
            }
            voltageTune += voltageStep;
            voltageTune = voltageTune > vctp.VoltageMax ? vctp.VoltageMax : voltageTune;
          }
        }
      }
      return tuneMinerGPUsResultList.ToList<ITuneMinerGPUsResult>();
    }

  }
  public class ClaymoreZECMinerProcess : ClaymoreMinerProcessAbstract
  {

    public ClaymoreZECMinerProcess(MinerSWAbstract computerSoftwareProgram, Command command, params object[] arguments) : base(computerSoftwareProgram, command, arguments)
    {
    }
  }
  public class ClaymoreETHDualMinerProcess : ClaymoreMinerProcessAbstract
  {
    public ClaymoreETHDualMinerProcess(MinerSWAbstract computerSoftwareProgram, Command command, params object[] arguments) : base(computerSoftwareProgram, command, arguments)
    {
    }
  }
}
