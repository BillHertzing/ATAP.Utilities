
using System;
using System.Collections.Generic;
using System.IO;


using Microsoft.Extensions.Configuration;
using ATAP.Utilities.HostedServices;

using StringConstantsVA = ATAP.Utilities.VoiceAttack.StringConstantsVA;


namespace ATAP.Utilities.VoiceAttack {
  public interface IData {
    public IConfigurationRoot ConfigurationRoot { get; set; }
    public dynamic StoredVAProxy { get; set; }
    public Dictionary<string, ObservableResetableTimer> TimerDisposeHandles { get; set; }
    public void Dispose();
  }

  public abstract class Data : IData {
    public IConfigurationRoot ConfigurationRoot { get; set; }
    public dynamic StoredVAProxy { get; set; }
    public Dictionary<string, ObservableResetableTimer> TimerDisposeHandles { get; set; }
    public Data(IConfigurationRoot configurationRoot, dynamic storedVAProxy) {
      ConfigurationRoot = configurationRoot;
      StoredVAProxy = storedVAProxy;
      TimerDisposeHandles = new Dictionary<string, ATAP.Utilities.HostedServices.ObservableResetableTimer>();
      #region Local Variables used inside .ctor
      TimeSpan ts;
      string durationAsString;
      #endregion
      // Create the MainTimer
      // Duration is from configuration
      durationAsString = configurationRoot.GetValue<string>(StringConstantsVA.MainTimerTimeSpanConfigRootKey, StringConstantsVA.MainTimerTimeSpanDefault);
      try {
        ts = TimeSpan.Parse(durationAsString);
      }
      catch (FormatException) {
        Serilog.Log.Debug("{0} {1}: durationAsString is {2} and cannot be parsed as a TimeSpan", "PluginVA", "Data(.ctor)", durationAsString);
        StoredVAProxy.WriteToLog($"durationAsString is {durationAsString} and cannot be parsed as a TimeSpan", "Red");
        throw new InvalidDataException($"durationAsString is {durationAsString} and cannot be parsed as a TimeSpan");
      }
      catch (OverflowException) {
        Serilog.Log.Debug("{0} {1}: durationAsString is {2} and is outside the range of a TimeSpan", "PluginVA", "Data(.ctor)", durationAsString);
        StoredVAProxy.WriteToLog($"durationAsString is {durationAsString} and is outside the range of a TimeSpan", "Red");
        throw new InvalidDataException($"durationAsString is {durationAsString} and is outside the range of a TimeSpan");
      }

      TimerDisposeHandles.Add(StringConstantsVA.MainTimerName, new ObservableResetableTimer(ts,
       new Action(() => {
         //Serilog.Log.Debug("{0} {1}: The MainObservableResetableTimer fired at {2}", "PluginVA", "MainTimerSubscriptionAction", e.SignalTime.ToString(StringConstantsVA.DATE_FORMAT));
         //StoredVAProxy.Command.WriteToLog($"The MainObservableResetableTimer fired at {e.SignalTime.ToString(StringConstantsVA.DATE_FORMAT)}", "Blue");
         Serilog.Log.Debug("{0} {1}: The MainObservableResetableTimer fired", "PluginVA", "MainTimerSubscriptionAction");
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
