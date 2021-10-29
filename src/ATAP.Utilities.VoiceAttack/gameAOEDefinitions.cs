

using System;
using System.Collections.Generic;
using System.IO;
using System.Diagnostics;
using System.Timers;
using System.Reflection;

using Serilog;

using Microsoft.Extensions.Configuration;
//using Microsoft.Extensions.Logging;
//using Microsoft.Extensions.Logging.Abstractions;

using System.Reactive;

using GenericHostExtensions = ATAP.Utilities.GenericHost.Extensions;
using ConfigurationExtensions = ATAP.Utilities.Configuration.Extensions;
using AOEStringConstants = ATAP.Utilities.VoiceAttack.Game.AOE.StringConstants;

namespace ATAP.Utilities.VoiceAttack.Game.AOE {

  public enum KindOfStructure {
    Dock,
    House,
    LumberCamp,
    MiningCamp,
    TownCenter,
  }

  public abstract class Structure {
    public Structure(KindOfStructure kind, decimal buildTimeInSeconds) {
      Kind = kind;
      BuildTimeInSeconds = buildTimeInSeconds;
    }

    public KindOfStructure Kind { get; set; }

    public decimal BuildTimeInSeconds { get; set; }

  }

  public class Dock : Structure {
    const decimal buildTimeInSecondsDock = 40;
    public Dock() : base(KindOfStructure.Dock, buildTimeInSecondsDock) {
    }
  }

  public class TownCenter : Structure {
    const decimal buildTimeInSecondsTownCenter = 120;
    public TownCenter() : base(KindOfStructure.Dock, buildTimeInSecondsTownCenter) {
    }
  }

}


