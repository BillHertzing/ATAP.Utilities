
using System;
using System.Collections.Generic;
using System.IO;
using System.Timers;


using Microsoft.Extensions.Configuration;
using ATAP.Utilities.HostedServices;

using AOEStringConstants = ATAP.Utilities.VoiceAttack.AOE.StringConstants;


namespace ATAP.Utilities.VoiceAttack {

  public class Data {
    public IConfigurationRoot ConfigurationRoot { get; set; }

    public dynamic StoredVAProxy { get; set; }

    public TimeSpan CurrentVillagerBuildTimeSpan { get; set; }
    public short CurrentNumVillagers { get; set; }
    public Dictionary<string, ObservableResetableTimer> TimerDisposeHandles { get; set; }

    public Data(IConfigurationRoot configurationRoot, dynamic storedVAProxy) {
      ConfigurationRoot = configurationRoot;
      StoredVAProxy = storedVAProxy;
      TimerDisposeHandles = new Dictionary<string, ATAP.Utilities.HostedServices.ObservableResetableTimer>();
      #region Local Variables used inside .ctor
      TimeSpan ts;
      string durationAsString;
      #endregion
      #region Initialize data for the create villagers loop
      // Initial value of CurrentVillagerBuildTimeSpan duration is from configuration
      durationAsString = configurationRoot.GetValue<string>(AOEStringConstants.VillagerBuildTimeSpanConfigRootKey, AOEStringConstants.VillagerBuildTimeSpanDefault);
      try {
        ts = TimeSpan.Parse(durationAsString);
      }
      catch (FormatException) {
        Serilog.Log.Debug("{0} {1}: durationAsString is {2} and cannot be parsed as a TimeSpan", "ATAPPlugin", "Data(.ctor)", durationAsString);
        StoredVAProxy.WriteToLog($"durationAsString is {durationAsString} and cannot be parsed as a TimeSpan", "Red");
        throw new InvalidDataException($"durationAsString is {durationAsString} and cannot be parsed as a TimeSpan");
      }
      catch (OverflowException) {
        Serilog.Log.Debug("{0} {1}: durationAsString is {2} and is outside the range of a TimeSpan", "ATAPPlugin", "Data(.ctor)", durationAsString);
        StoredVAProxy.WriteToLog($"durationAsString is {durationAsString} and is outside the range of a TimeSpan", "Red");
        throw new InvalidDataException($"durationAsString is {durationAsString} and is outside the range of a TimeSpan");
      }

      CurrentVillagerBuildTimeSpan = ts;
      CurrentNumVillagers = 0;
      #endregion

      // Create the MainTimer
      // Duration is from configuration
      durationAsString = configurationRoot.GetValue<string>(StringConstants.MainTimerTimeSpanConfigRootKey, StringConstants.MainTimerTimeSpanDefault);
      try {
        ts = TimeSpan.Parse(durationAsString);
      }
      catch (FormatException) {
        Serilog.Log.Debug("{0} {1}: durationAsString is {2} and cannot be parsed as a TimeSpan", "ATAPPlugin", "Data(.ctor)", durationAsString);
        StoredVAProxy.WriteToLog($"durationAsString is {durationAsString} and cannot be parsed as a TimeSpan", "Red");
        throw new InvalidDataException($"durationAsString is {durationAsString} and cannot be parsed as a TimeSpan");
      }
      catch (OverflowException) {
        Serilog.Log.Debug("{0} {1}: durationAsString is {2} and is outside the range of a TimeSpan", "PlATAPPluginugin", "Data(.ctor)", durationAsString);
        StoredVAProxy.WriteToLog($"durationAsString is {durationAsString} and is outside the range of a TimeSpan", "Red");
        throw new InvalidDataException($"durationAsString is {durationAsString} and is outside the range of a TimeSpan");
      }

      TimerDisposeHandles.Add(StringConstants.MainTimerName, new ObservableResetableTimer(ts,
       new Action(() => {
         // Serilog.Log.Debug("{0} {1}: The MainObservableResetableTimer fired at {2}", "ATAPPlugin", "OnMainTimerEvent", e.SignalTime.ToString(StringConstants.DATE_FORMAT));
         // StoredVAProxy.Command.WriteToLog($"The MainObservableResetableTimer fired at {e.SignalTime.ToString(StringConstants.DATE_FORMAT)}", "Blue");
         Serilog.Log.Debug("{0} {1}: The MainObservableResetableTimer fired", "ATAPPlugin", "OnMainTimerEvent");
         StoredVAProxy.Command.WriteToLog($"The MainObservableResetableTimer fired", "Purple");
       })));

    }

    #region IDisposable Support
    private bool disposedValue = false; // To detect redundant calls

    protected virtual void Dispose(bool disposing) {
      if (!disposedValue) {
        if (disposing) {
          // dispose of the TimerDisposeHandle collection
          foreach (var timerName in TimerDisposeHandles.Keys) {
            TimerDisposeHandles.Remove(timerName);
          }
        }
        disposedValue = true;
      }
    }

    // This code added to correctly implement the disposable pattern.
    public void Dispose() {
      // Do not change this code. Put cleanup code in Dispose(bool disposing) above.
      Dispose(true);
    }
    #endregion

  }
}

namespace ATAP.Utilities.VoiceAttack.AOE {

  public class Data : ATAP.Utilities.VoiceAttack.Data {

    public TimeSpan CurrentVillagerBuildTimeSpan { get; set; }
    public short CurrentNumVillagers { get; set; }

    public Data(IConfigurationRoot configurationRoot, dynamic storedVAProxy) :base(configurationRoot, storedVAProxy) {
      #region Local Variables used inside .ctor
      TimeSpan ts;
      string durationAsString;
      short n;
      string shortAsString;
      #endregion
      #region Initialize data for the create villagers loop
      // Initial value of CurrentVillagerBuildTimeSpan duration is from configuration
      durationAsString = configurationRoot.GetValue<string>(StringConstants.VillagerBuildTimeSpanConfigRootKey, StringConstants.VillagerBuildTimeSpanDefault);
      try {
        ts = TimeSpan.Parse(durationAsString);
      }
      catch (FormatException) {
        Serilog.Log.Debug("{0} {1}: durationAsString is {2} and cannot be parsed as a TimeSpan", "ATAPPlugin", "Data(.ctor)", durationAsString);
        StoredVAProxy.WriteToLog($"durationAsString is {durationAsString} and cannot be parsed as a TimeSpan", "Red");
        throw new InvalidDataException($"durationAsString is {durationAsString} and cannot be parsed as a TimeSpan");
      }
      catch (OverflowException) {
        Serilog.Log.Debug("{0} {1}: durationAsString is {2} and is outside the range of a TimeSpan", "ATAPPlugin", "Data(.ctor)", durationAsString);
        StoredVAProxy.WriteToLog($"durationAsString is {durationAsString} and is outside the range of a TimeSpan", "Red");
        throw new InvalidDataException($"durationAsString is {durationAsString} and is outside the range of a TimeSpan");
      }

      CurrentVillagerBuildTimeSpan = ts;

      shortAsString = configurationRoot.GetValue<string>(AOEStringConstants.InitialNumVillagersConfigRootKey, AOEStringConstants.InitialNumVillagersDefault);
      try {
        n = short.Parse(shortAsString);
      }
      catch (FormatException) {
        Serilog.Log.Debug("{0} {1}: shortAsString is {2} and cannot be parsed as a short", "ATAPPlugin", "Data(.ctor)", shortAsString);
        StoredVAProxy.WriteToLog($"shortAsString is {shortAsString} and cannot be parsed as a short", "Red");
        throw new InvalidDataException($"shortAsString is {shortAsString} and cannot be parsed as a TishortmeSpan");
      }
      catch (OverflowException) {
        Serilog.Log.Debug("{0} {1}: shortAsString is {2} and is outside the range of a short", "ATAPPlugin", "Data(.ctor)", shortAsString);
        StoredVAProxy.WriteToLog($"shortAsString is {shortAsString} and is outside the range of a short", "Red");
        throw new InvalidDataException($"shortAsString is {shortAsString} and is outside the range of a short");
      }
CurrentNumVillagers = n;
      #endregion
    }

  }

}
