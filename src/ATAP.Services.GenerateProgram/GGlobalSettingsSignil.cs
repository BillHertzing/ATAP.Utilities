
using System;
using System.Collections.Generic;
using System.Text;

using ATAP.Utilities.Philote;
namespace GenerateProgram {

  public class GGlobalSettingsSignil : IGGlobalSettingsSignil {
    public GGlobalSettingsSignil(
     ICollection<string> targetFrameworks = default
) {
      TargetFrameworks = targetFrameworks ?? throw new ArgumentNullException(nameof(targetFrameworks));
      //Philote = new Philote<GSolutionSignil>();
    }
    public ICollection<string> TargetFrameworks { get; }
    public Philote<GSolutionSignil> Philote { get; }
  }
}
