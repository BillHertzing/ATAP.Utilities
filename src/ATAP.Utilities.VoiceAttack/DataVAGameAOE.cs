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
using StringConstantsVAGameAOE = ATAP.Utilities.VoiceAttack.Game.AOE.StringConstants;


namespace ATAP.Utilities.VoiceAttack.Game.AOE {

  public interface IData : ATAP.Utilities.VoiceAttack.Game.IData {
    public List<Structure> Structures { get; set; }
    public TimeSpan CurrentVillagerBuildTimeSpan { get; set; }
    public short CurrentNumVillagers { get; set; }
    public new void Dispose();

  }

  public abstract class Data : ATAP.Utilities.VoiceAttack.Game.Data, IData {
    public List<Structure> Structures { get; set; }
    public TimeSpan CurrentVillagerBuildTimeSpan { get; set; }
    public short CurrentNumVillagers { get; set; }
    public Data(IConfigurationRoot configurationRoot, dynamic vaProxy) : base(configurationRoot, (object)vaProxy) {
      #region Local Variables used inside .ctor
      TimeSpan ts;
      string durationAsString;
      short n;
      string shortAsString;
      #endregion
      #region Initialize data for the create villagers loop
      // Initial value of CurrentVillagerBuildTimeSpan duration is from configuration
      durationAsString = configurationRoot.GetValue<string>(StringConstantsVAGameAOE.VillagerBuildTimeSpanConfigRootKey, StringConstantsVAGameAOE.VillagerBuildTimeSpanDefault);
      try {
        ts = TimeSpan.Parse(durationAsString);
      }
      catch (FormatException) {
        Serilog.Log.Debug("{0} {1}: durationAsString is {2} and cannot be parsed as a TimeSpan", "ATAPPluginGameAOE", "Data(.ctor)", durationAsString);
        StoredVAProxy.WriteToLog($"durationAsString is {durationAsString} and cannot be parsed as a TimeSpan", "Red");
        throw new InvalidDataException($"durationAsString is {durationAsString} and cannot be parsed as a TimeSpan");
      }
      catch (OverflowException) {
        Serilog.Log.Debug("{0} {1}: durationAsString is {2} and is outside the range of a TimeSpan", "ATAPPluginGameAOE", "Data(.ctor)", durationAsString);
        StoredVAProxy.WriteToLog($"durationAsString is {durationAsString} and is outside the range of a TimeSpan", "Red");
        throw new InvalidDataException($"durationAsString is {durationAsString} and is outside the range of a TimeSpan");
      }

      CurrentVillagerBuildTimeSpan = ts;

      shortAsString = configurationRoot.GetValue<string>(StringConstantsVAGameAOE.InitialNumVillagersConfigRootKey, StringConstantsVAGameAOE.InitialNumVillagersDefault);
      try {
        n = short.Parse(shortAsString);
      }
      catch (FormatException) {
        Serilog.Log.Debug("{0} {1}: shortAsString is {2} and cannot be parsed as a short", "ATAPPluginGameAOE", "Data(.ctor)", shortAsString);
        StoredVAProxy.WriteToLog($"shortAsString is {shortAsString} and cannot be parsed as a short", "Red");
        throw new InvalidDataException($"shortAsString is {shortAsString} and cannot be parsed as a TishortmeSpan");
      }
      catch (OverflowException) {
        Serilog.Log.Debug("{0} {1}: shortAsString is {2} and is outside the range of a short", "ATAPPluginGameAOE", "Data(.ctor)", shortAsString);
        StoredVAProxy.WriteToLog($"shortAsString is {shortAsString} and is outside the range of a short", "Red");
        throw new InvalidDataException($"shortAsString is {shortAsString} and is outside the range of a short");
      }
      CurrentNumVillagers = n;
      #endregion

      #region Initialize Structures
      Structures = new();
      Structures.Add(new TownCenter());
      #endregion
    }
    #region IDisposable Support
    private bool disposedValue = false; // To detect redundant calls
    protected new virtual void Dispose(bool disposing) {
      if (!disposedValue) {
        if (disposing) {
          // dispose of anything needing disposing
          base.Dispose();
        }
      }
      disposedValue = true;
    }
    // This code added to correctly implement the disposable pattern.
    public new void Dispose() {
      // Do not change this code. Put cleanup code in Dispose(bool disposing) above.
      Dispose(true);
    }
    #endregion
  }
}
