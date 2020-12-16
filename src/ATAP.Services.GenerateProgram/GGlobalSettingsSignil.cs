
using System;
using System.Collections.Generic;
using System.Text;

using ATAP.Utilities.Philote;
namespace GenerateProgram {


  public class GGlobalSettingsSignil : IGGlobalSettingsSignil, IGGlobalSettingsSignil1 {
    public GGlobalSettingsSignil(
     ICollection<string> targetFrameworks = default
) {
      TargetFrameworks = targetFrameworks ?? throw new ArgumentNullException(nameof(targetFrameworks));
      //Philote = new Philote<GSolutionSignil>();
    }
    public ICollection<string> TargetFrameworks { get; }
  }
}
