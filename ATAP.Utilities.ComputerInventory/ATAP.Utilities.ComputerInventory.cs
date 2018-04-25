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
        readonly ComputerHardware computerHardware;
        readonly ComputerSoftware computerSoftware;
        ComputerProcesses computerProcesses;

        public ComputerHardware ComputerHardware => computerHardware;

        public ComputerSoftware ComputerSoftware => computerSoftware;

        public ComputerProcesses ComputerProcesses { get => computerProcesses; set => computerProcesses = value; }

        public ComputerInventory(ComputerHardware computerHardware, ComputerSoftware computerSoftware, ComputerProcesses computerProcesses)
        {
            this.computerHardware = computerHardware ?? throw new ArgumentNullException(nameof(computerHardware));
            this.computerSoftware = computerSoftware ?? throw new ArgumentNullException(nameof(computerSoftware));
            this.computerProcesses = computerProcesses ?? throw new ArgumentNullException(nameof(computerProcesses));
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
            throw new NotImplementedException();
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
