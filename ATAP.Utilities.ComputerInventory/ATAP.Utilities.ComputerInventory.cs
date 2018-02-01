using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Linq;
using Itenso.TimePeriod;
using Newtonsoft.Json;
using Newtonsoft.Json.Converters;
using Swordfish.NET.Collections;

namespace ATAP.Utilities.ComputerInventory
{

    public class ComputerInventory
    {
        readonly ComputerHW computerHW;
        readonly ComputerSoftware computerSoftware;

        public ComputerHW ComputerHW => computerHW;

        public ComputerSoftware ComputerSoftware => computerSoftware;

        public ComputerInventory(ComputerHW computerHW, ComputerSoftware computerSoftware)
        {
            this.computerHW = computerHW ?? throw new ArgumentNullException(nameof(computerHW));
            this.computerSoftware = computerSoftware ?? throw new ArgumentNullException(nameof(computerSoftware));
        }

        public static ComputerInventory InventoryThisComputer()
        {
            throw new NotImplementedException();
        }
        //ToDo: Implement writing a ComputerInventory object to a set of Configuration Settings
        public static Dictionary<string, string> ToConfigurationSettings(ComputerInventory computerInventory) {
            throw new NotImplementedException();
        }
        //ToDo: Implement creating a ComputerInventory object from a set of Configuration Settings
        public ComputerInventory (Dictionary<string, string> configurationSettings)
        {
            
        }
        // Constructor based on builtin and hostname
        public ComputerInventory ()
        {
            ComputerInventory ci;
            Motherboard motherboard;
            CPU[] cPUs;
            VideoCard vc;
            int numVideoCards;
            VideoCard[] videoCards;
            switch(Environment.GetEnvironmentVariable("COMPUTERNAME"))
            {
                case "NCAT016":
                    motherboard = new Motherboard(MotherboardMaker.ASUS, "ToDo:makeSocketanEnum");
                    cPUs = new CPU[1] { new CPU(CPUMaker.Intel) };
                    VideoCardDiscriminatingCharacteristics vcdc = VideoCardsKnown.TuningParameters.Keys.Where(x => (x.VideoCardMaker ==
                        VideoCardMaker.ASUS
                        && x.GPUMaker ==
                        GPUMaker.NVIDEA))
                                                                      .Single();
                    vc = new VideoCard(vcdc,
                                       "ToDo:readfromcard",
                                       "ToDo:readfromcard",
                                       false,
                                       -1,
                                       -1,
                                       -1,
                                       -1,
                                       new PowerConsumption() {
                    Period =
                        new TimeSpan(0,
                                     1,
                                     0),
                        Watts = 1000
                    },
                                       new TempAndFan() { FanPct = 50.0, Temp = 60 });
                    numVideoCards = 1;
                    videoCards = new VideoCard[1] { vc };
                    ci = new ComputerHW(cPUs, motherboard, videoCards, new TimeBlock(DateTime.UtcNow));
                    break;
                default:
                    throw new ArgumentException("unknown hostname");
                    //break;
            }
           
        }

       
    }


// Add an enumeration for the supported cpu names
    // Add an enumeration for the supported cpu sockets
    // Add an enumeration for the supported motherboardMemorymakers
    // Add an enumeration for the supported Disk makers
    // Add an enumeration for the supported Powersupply makers

/*
Abstract:
ComputerInventory
Moment or span?
Motherboard
CPU
Memory
Disks
PowerSupply
USBPorts
VideoCards
Software
Drivers
Mining Programs (includes both name and version)
AceAgent

Concrete:
"FactoryReset", AKA AllDummy (moment, 1/1/1980)
"CurrentActual" (span, from start of program (or last change) to now())
"Profile or hypothetical" (span or moment, can include planned time spans)

ConcurrentObservableDictionary<TimePeriod, ComputerInventory> changeHistoryComputerInventory (each has non-overlapping periods, should be in the aggregate a contiguous span).

*****
Current actual Inventory
is there a changeHistoryComputerInventory in the configuration settings, or a ChangeHistoryComputerInventoryFile (or DB)?
yes - create and load a change history object, make currentActual = latest history
is there a currentComputerInventory in the configuration settings, or a CurrentComputerInventoryFile (or DB)?
yes - compare currentActual
if there is nothing, currentComputerInventory = FactoryReset, and changeHistory = currentComputerInventory
create foundComputerInventory ( run the take inventory method)
if foundComputerInventory == currentComputerInventory, done, else currentComputerInventory = foundComputerInventory and add currentComputerInventory to changeHistoryComputerInventory
at this point, the currentComputerInventory object is up to date

* */
}
