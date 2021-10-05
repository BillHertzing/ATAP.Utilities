namespace ATAP.Utilities.VoiceAttack {

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

  public static class T {
    public static void StartGame() {

    }
  }
}


