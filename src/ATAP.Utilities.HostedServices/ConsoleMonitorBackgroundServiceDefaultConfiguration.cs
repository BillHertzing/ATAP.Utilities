using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace ATAP.Utilities.HostedServices {
  static public class GenerateProgramBackgroundServiceDefaultConfiguration {
    // Create the minimal set of Configuration settings that this service needs to startup and run in production
    public static Dictionary<string, string> Production =
    new Dictionary<string, string> {
    };
  }
}

