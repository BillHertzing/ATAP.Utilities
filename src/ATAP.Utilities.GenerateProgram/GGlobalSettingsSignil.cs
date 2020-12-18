
using System;
using System.Collections.Generic;
using System.Text;

using ATAP.Utilities.Philote;
namespace ATAP.Utilities.GenerateProgram {

  public class GGlobalSettingsSignil : IGGlobalSettingsSignil {
    public GGlobalSettingsSignil(
     ICollection<string> targetFrameworks = default
) {
      TargetFrameworks = targetFrameworks ?? throw new ArgumentNullException(nameof(targetFrameworks));
      Philote = new Philote<IGGlobalSettingsSignil>();
    }
    public ICollection<string> TargetFrameworks { get; init; }
    public IPhilote<IGGlobalSettingsSignil> Philote { get; init; }
  }
}
