
using System;
using System.Collections.Generic;
using System.Text;

using ATAP.Utilities.StronglyTypedId;
namespace ATAP.Utilities.GenerateProgram {

  public class GGlobalSettingsSignil : IGGlobalSettingsSignil {
    public GGlobalSettingsSignil(
     ICollection<string> defaultTargetFrameworks = default
    ) {
      DefaultTargetFrameworks = defaultTargetFrameworks ?? throw new ArgumentNullException(nameof(defaultTargetFrameworks));


    }
    public ICollection<string> DefaultTargetFrameworks { get; }
    public  IGGlobalSettingsSignilId Id { get; }
  }
}






