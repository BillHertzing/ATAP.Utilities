
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
using AutoMapper;

using StringConstantsVA = ATAP.Utilities.VoiceAttack.StringConstantsVA;

namespace ATAP.Utilities.VoiceAttack {
  public interface IData {
    IConfigurationRoot ConfigurationRoot { get; set; }
    dynamic StoredVAProxy { get; set; }
    ObservableResetableTimersHostedServiceData ObservableResetableTimersHostedServiceData { get; set; }
        TimeSpan MainTimerElapsedTimeSpan { get; set; }

    // The object for controlling the speech synthesis engine (voice).
    SpeechSynthesizer SpeechSynthesizer { get; set; }

    IMapper Mapper { get; set; }
    void Dispose();
  }

  public abstract class Data : IData {
    public IConfigurationRoot ConfigurationRoot { get; set; }
    public dynamic StoredVAProxy { get; set; }
    public ObservableResetableTimersHostedServiceData ObservableResetableTimersHostedServiceData { get; set; }
    // The object for controlling the speech synthesis engine (voice).
    public SpeechSynthesizer SpeechSynthesizer { get; set; }
    public TimeSpan MainTimerElapsedTimeSpan { get; set; }
    public IMapper Mapper { get; set; }

    public Data(IConfigurationRoot configurationRoot, dynamic storedVAProxy) {
      ConfigurationRoot = configurationRoot;
      StoredVAProxy = storedVAProxy;
      ObservableResetableTimersHostedServiceData = new();

      SpeechSynthesizer = new();
      // Configure MessageQueue per configurationRoot if needed at this level someday.
      // Currint (initial) development effort is towards AOEII and AOEIV, and only uses one message queue, kept at the VA.Game.AOE data
      // Create a Mapper for any message/messageDto sent over this level's MessageQueue
      // Mapper = new();

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
