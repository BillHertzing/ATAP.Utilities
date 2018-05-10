using ATAP.Utilities.ComputerInventory;
using Swordfish.NET.Collections;
using System;
using System.Collections.Generic;
using System.Text;
using System.Threading.Tasks;
using UnitsNet;
using ATAP.Utilities.ComputerInventory.Enumerations;
using ATAP.Utilities.ComputerInventory.Models;

namespace ATAP.Utilities.CryptoCoin
{
    public abstract class MinerProcess : ComputerProcess
    {
        public MinerProcess(MinerSW computerSoftwareProgram, params object[] arguments) : base(computerSoftwareProgram, arguments)
        {
        }

        //ToDo: Add a cancellation token
        public abstract Task<IMinerStatus> StatusFetchAsync();

        public virtual async Task<List<TuneMinerGPUsResult>> TuneMiners()
        {
            bool fine = true;
            //ToDo asking for highest HashRate or most efficient HashRate?
            // create the collection of GPUs to tune
            MinerGPU[] minerGPUsToTune = new MinerGPU[1];
            // create the collection of MinerSWs to tune
            MinerSW[] minerSWsToTune = new MinerSW[1];
            // create the results
            List<TuneMinerGPUsResult> tuneMinerGPUsResultList = new List<TuneMinerGPUsResult>();
            foreach (var msw in minerSWsToTune)
            {
                foreach (var mg in minerGPUsToTune)
                {
                    // Select the tuning strategy for this MinerSW and this VideoCard
                    var vcdc = mg.VideoCardDiscriminatingCharacteristics;
                    var vctp = VideoCardsKnown.TuningParameters[vcdc];
                    // Calculate the step for each parameter
                    int memoryClockStep = (vctp.MemoryClockMax - vctp.MemoryClockMin) / (fine ? 1 : 5);
                    int coreClockStep = (vctp.CoreClockMax - vctp.CoreClockMin) / (fine ? 1 : 5);
                    double voltageStep = (vctp.VoltageMax - vctp.VoltageMin) / (fine ? 0.01 : 0.05);
                    // memoryClock Min, max, step
                    // CoreClock Min, max, step
                    // memoryVoltage min, max, step
                    int memoryClockTune = vctp.MemoryClockMin;
                    int coreClockTune = vctp.CoreClockMin;
                    double voltageTune = vctp.VoltageMin;
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
                                var minerStatus = await StatusFetchAsync();
                                ConcurrentObservableDictionary<Coin, HashRate> hashRatesTune = new ConcurrentObservableDictionary<Coin, HashRate> { { Coin.ETH, new HashRate(1000.0, new TimeSpan(0,0,1)) } };
                                Power powerConsumptionTune = new Power();
                                // Or Detect a minerSW stoppage or detect a rig reboot
                                // Record the results for this combination of msw,mvc,mClock,cClock,and mVoltage
                                tuneMinerGPUsResultList.Add(new TuneMinerGPUsResult(coreClockTune, memoryClockTune, voltageTune, hashRatesTune, powerConsumptionTune));
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
            return tuneMinerGPUsResultList;
        }

    }

}
