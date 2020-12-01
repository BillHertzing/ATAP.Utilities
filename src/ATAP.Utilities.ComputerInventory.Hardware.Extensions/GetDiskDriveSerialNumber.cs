using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
//using System.Management;
//using System.Management.Instrumentation;
using System.Threading;

namespace ATAP.Utilities.ComputerInventory.Hardware {
  public static partial class StaticExtensions {
    // ToDo: Figure out how to use it in .Net Full, and figure out how to not try and include in for Standard and Core
    //public static async Task<string> GetDiskDriveSerialNumber(string? driveLetterString, CancellationToken cancellationToken) {
    //  // Helper method to reduce code clutter
    //  static void CheckAndHandleCancellationToken(int checkpointNumber, CancellationToken cancellationToken) {
    //    // Helper method to reduce code clutter
    //    // check CancellationToken to see if this task is cancelled
    //    if (cancellationToken.IsCancellationRequested) {
    //      // ToDo localize the Log message
    //      // logger.LogDebug.Debug($"in ConvertFileSystemToGraphAsyncTask: Cancellation requested, checkpoint numbe {checkpointNumber}");
    //      cancellationToken.ThrowIfCancellationRequested();
    //    }
    //  }
    //  var checkpointNumber = 1;
    //  CheckAndHandleCancellationToken(checkpointNumber++, cancellationToken);
    //  // ToDo: define stringconstants and configuration items for defaultDriveLetterString
    //  //ToDo: Figure out a *nix equivalent
    //  if (string.IsNullOrEmpty(driveLetterString)) {
    //    driveLetterString = "E";
    //  }
    //  // ToDo: Validate that the driveLetterString meets the requirements// Regex.match "[A-Z]" or "[A-Z]:\\", and if no trailing slash, make it so
    //  driveLetterString += ":\\";
    //  //Create the ManagementObject, passing it the driveLetterString as the DeviceID using WQL
    //  ManagementObject diskDrive = new ManagementObject("Win32_LogicalDisk.DeviceID=\"" + driveLetterString );
    //  // Query the  WMI subsystem
    //  try {
    //    diskDrive.Get();
    //  }
    //  catch (Exception e) {// ToDo specific exceptions
    //    diskDrive.Dispose();
    //    throw; // ToDo: probab return a serial number of all zeros, and a specific result type, that would include the exception specifics
    //  }
    //  string seriallNumber;
    //  seriallNumber = diskDrive["VolumeSerialNumber"].ToString(); // ToDo: wrap in a try to ensure the key exists
    //  return seriallNumber;
    //}
  }
}

