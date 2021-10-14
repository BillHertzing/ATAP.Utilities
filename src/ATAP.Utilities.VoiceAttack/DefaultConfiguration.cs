
using System;
using System.Collections.Generic;

namespace ATAP.Utilities.VoiceAttack {
  public static class DefaultConfigurationGenericHost {
    public static Dictionary<string, string> Production = new() {
      { StringConstantsVA.ProfileConfigRootKey, StringConstantsVA.ProfileNameDefault },
      { StringConstantsVA.TemporaryDirectoryBaseConfigRootKey, StringConstantsVA.TemporaryDirectoryBaseDefault },
      { StringConstantsVA.PluginPathBaseConfigRootKey, StringConstantsVA.PluginPathBaseDefault },
      { StringConstantsVA.EnableProgressConfigRootKey, StringConstantsVA.EnableProgressDefault },
      { StringConstantsVA.PersistencePathBaseDefault, StringConstantsVA.PersistencePathBaseConfigRootKey },
    };
  }

  public static class DefaultConfigurationVA {
    public static Dictionary<string, string> Production = new() {
      { StringConstantsVA.MainTimerTimeSpanConfigRootKey, StringConstantsVA.MainTimerTimeSpanDefault },
    };
  }
}

namespace ATAP.Utilities.VoiceAttack.Game {
  public static class DefaultConfiguration {
    public static Dictionary<string, string> Production = new() {
    };
  }
}

namespace ATAP.Utilities.VoiceAttack.Game.AOE {
  public static class DefaultConfiguration {
    public static Dictionary<string, string> Production = new() {
    };
  }
}

namespace ATAP.Utilities.VoiceAttack.Game.AOE.II {
  public static class DefaultConfiguration {
    public static Dictionary<string, string> Production = new() {
    };
  }
}
