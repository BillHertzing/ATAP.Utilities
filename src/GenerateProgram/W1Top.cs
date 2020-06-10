using System;
using System.Collections.Generic;
using System.Diagnostics.Eventing.Reader;
using System.IO;
using System.Linq.Expressions;
using System.Text;
using System.Threading;
using ATAP.Utilities.Philote;
//using Microsoft.FSharp.Core;

namespace GenerateProgram {


  public interface IW1Top {
    String BasePath { get; set; }
    Encoding Encoding { get;  }
    bool? Force { get; }
    CancellationToken? Ct { get;  }
    //Dictionary<string, object> Session { get; set; }
    //void Write();
  }

  public class W1Top : IW1Top {
    public W1Top(string basePath = "", Encoding? encoding = default, bool? force = default,List<string> nonReleasedPackages = default,
      CancellationToken? ct = default) {
      BasePath = basePath ?? throw new ArgumentNullException(nameof(basePath));
      Encoding = encoding == default ? Encoding.UTF8 : encoding;
      Force = force == default ? false : force;
      NonReleasedPackages = nonReleasedPackages == default ? new List<string>() : nonReleasedPackages;
      Ct = ct;
     
      var dirInfo = new DirectoryInfo(BasePath);
      if (!dirInfo.Exists) {
        if (!(bool)Force) {
          //ToDo: Log exception
          throw new Exception(message: $"Base directory for Generated code does not exist (try force=true): {BasePath}");
        }
        else {
          try {
            dirInfo.Create();
          }
          catch (System.IO.IOException e) {
            //ToDo: Log exception
            throw new Exception(message: $"Could Not create base directory for Generated code: {BasePath}", innerException: e);
          }
        }
      }
    }

    public String BasePath { get; set; }
    public Encoding Encoding { get; set; }
    public bool? Force { get; set; }
    public List<string> NonReleasedPackages { get; set; }
    public CancellationToken? Ct { get; set; }
  }
}
