using System;
using System.Collections.Generic;
using ATAP.Utilities.GenerateProgram;
using ATAP.Utilities.Philotes;
namespace ATAP.Services.GenerateProgram {
   static class EntryPoints {
    public static IGGenerateProgramResult GenerateProgramEntryPoint1(Philote<GAssemblyGroupSignil> gAssemblyGroupSignilKey, Philote<GGlobalSettingsSignil> gGlobalSettingsSignilKey, Philote<GSolutionSignil> gSolutionSignilKey) {

      // Populate the 3 Signils from the DB using their respective Key

      GGenerateProgramResult gGenerateProgramResult = ATAP.Utilities.GenerateProgramEntryPoint1(gAssemblyGroupSignil, gGlobalSettingsSignil, gGlobalKeysSignil);
return gGenerateProgramResult;
    }
  }
}
