
using System;
using System.Collections.Generic;
using System.IO;
using System.Reactive;
using System.Reactive.Concurrency;
using System.Reactive.Linq;
using System.Reactive.Subjects;


using Microsoft.Extensions.Configuration;
using ATAP.Utilities.HostedServices;
using ATAP.Utilities.MessageQueue;

using System.Speech.Synthesis;

using StringConstantsVA = ATAP.Utilities.VoiceAttack.StringConstantsVA;

namespace ATAP.Utilities.VoiceAttack {
  public interface IData {
    public IConfigurationRoot ConfigurationRoot { get; set; }
    public dynamic StoredVAProxy { get; set; }
    public ObservableResetableTimersHostedServiceData ObservableResetableTimersHostedServiceData { get; set; }
    // The object for controlling the speech synthesis engine (voice).
    public SpeechSynthesizer SpeechSynthesizer { get; set; }
    public void Dispose();
  }

  public abstract class Data : IData {
    public IConfigurationRoot ConfigurationRoot { get; set; }
    public dynamic StoredVAProxy { get; set; }
    public ObservableResetableTimersHostedServiceData ObservableResetableTimersHostedServiceData { get; set; }
    // The object for controlling the speech synthesis engine (voice).
    public SpeechSynthesizer SpeechSynthesizer { get; set; }
    public TimeSpan MainTimerElapsedTimeSpan { get; set; }
    public Data(IConfigurationRoot configurationRoot, dynamic storedVAProxy) {
      ConfigurationRoot = configurationRoot;
      StoredVAProxy = storedVAProxy;
      ObservableResetableTimersHostedServiceData = new();

      SpeechSynthesizer = new();
      // Configure MessageQueue per configurationRoot if needed at this level someday.
      // Currint (initial) development effort is towards AOEII and AOEIV, and only uses one message queue, kept at the VA.Game.AOE data

      #region Local Variables used inside .ctor
      string durationAsString;
      #endregion
      // Create the MainTimer
      // Duration is from configuration
      durationAsString = configurationRoot.GetValue<string>(StringConstantsVA.MainTimerTimeSpanConfigRootKey, StringConstantsVA.MainTimerTimeSpanDefault);
      TimeSpan durationAsTimeSpan;
      try {
        durationAsTimeSpan = TimeSpan.Parse(durationAsString);
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

      ObservableResetableTimersHostedServiceData.AddInterval(StringConstantsVA.MainTimerName, true, durationAsTimeSpan, new Action(() => {
        MainTimerElapsedTimeSpan += durationAsTimeSpan;
        Serilog.Log.Debug("{0} {1}: The MainObservableResetableTimer fired, the MainTimerElapsedTimeSpan is {2}", "PluginVA", "MainTimerSubscriptionAction", MainTimerElapsedTimeSpan);
        StoredVAProxy.WriteToLog($"The MainObservableResetableTimer fired, the MainTimerElapsedTimeSpan is {MainTimerElapsedTimeSpan}", "Purple");
      }));
      // debug
    }
    #region IDisposable Support
    private bool disposedValue = false; // To detect redundant calls
    protected virtual void Dispose(bool disposing) {
      if (!disposedValue) {
        if (disposing) {
          // dispose of the ObservableResetableTimersHostedServiceData, which will handle disposing of any active timers
          ObservableResetableTimersHostedServiceData.Dispose();
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
