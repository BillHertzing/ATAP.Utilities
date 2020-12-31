
using System;
using System.Collections.Generic;
using System.Text;

using ATAP.Utilities.Philote;
namespace ATAP.Utilities.GenerateProgram {

  public class GGlobalSettingsSignil : IGGlobalSettingsSignil {
    public GGlobalSettingsSignil(
     ICollection<string> defaultTargetFrameworks = default
    ) {
      DefaultTargetFrameworks = defaultTargetFrameworks ?? throw new ArgumentNullException(nameof(defaultTargetFrameworks));
      Philote = new Philote<IGGlobalSettingsSignil>();
    }
    public ICollection<string> DefaultTargetFrameworks { get; }
    public IPhilote<IGGlobalSettingsSignil> Philote { get; }
  }
}
