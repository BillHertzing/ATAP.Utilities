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


namespace ATAP.Utilities.VoiceAttack.Game.AOE.II {

  public interface IData : ATAP.Utilities.VoiceAttack.Game.AOE.IData {
    public new void Dispose();
  }
  public class Data : ATAP.Utilities.VoiceAttack.Game.AOE.Data, IData {
    public Data(IConfigurationRoot configurationRoot, dynamic vaProxy) : base(configurationRoot, (object)vaProxy) {
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
