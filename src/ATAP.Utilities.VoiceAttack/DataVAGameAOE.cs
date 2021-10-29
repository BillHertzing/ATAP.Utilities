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

using ATAP.Utilities.MessageQueue;
using ATAP.Utilities.MessageQueue.Shim.RabbitMQT;

using ATAP.Utilities.Serializer;

using GenericHostExtensions = ATAP.Utilities.GenericHost.Extensions;
using ConfigurationExtensions = ATAP.Utilities.Configuration.Extensions;
using StringConstantsVAGameAOE = ATAP.Utilities.VoiceAttack.Game.AOE.StringConstants;


namespace ATAP.Utilities.VoiceAttack.Game.AOE {


  public interface IData : ATAP.Utilities.VoiceAttack.Game.IData {
     List<Structure> Structures { get; set; }
     TimeSpan CurrentVillagerBuildTimeSpan { get; set; }
     short CurrentNumVillagers { get; set; }
     IMessageQueueAbstract<SendMessageResults> MessageQueue { get; set; }
     ISerializer Serializer { get; set; }

      new void Dispose();

  }

  public abstract class Data : ATAP.Utilities.VoiceAttack.Game.Data, IData {
    public List<Structure> Structures { get; set; }
    public TimeSpan CurrentVillagerBuildTimeSpan { get; set; }
    public short CurrentNumVillagers { get; set; }
    public IMessageQueueAbstract<SendMessageResults> MessageQueue { get; set; }
    public ISerializer Serializer { get; set; }

    public Data(IConfigurationRoot configurationRoot, dynamic vaProxy) : base(configurationRoot, (object)vaProxy) {
    }

    public VoiceAttackActionWithDelay FromJson(string jsonString) {
      // Serialize from JSON using specified Serializer
      return Serializer.Deserialize<VoiceAttackActionWithDelay>(jsonString);
    }
    public string ToJson(VoiceAttackActionWithDelay voiceAttackActionWithDelay) {
      // Serialize to JSON using specified Serializer
      return Serializer.Serialize(voiceAttackActionWithDelay);
    }
    public byte[] ToByteArray(VoiceAttackActionWithDelay voiceAttackActionWithDelay) {
      // Serialize to JSON using specified Serializer
      return System.Text.Encoding.UTF8.GetBytes(Serializer.Serialize(voiceAttackActionWithDelay));
    }
    public VoiceAttackActionWithDelay FromByteArray(byte[] message) {
      return FromJson(BitConverter.ToString(message));
    }


    #region IDisposable Support
    private bool disposedValue = false; // To detect redundant calls
    protected new virtual void Dispose(bool disposing) {
      if (!disposedValue) {
        if (disposing) {
          // dispose of anything needing disposing
          MessageQueue.Dispose();
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
