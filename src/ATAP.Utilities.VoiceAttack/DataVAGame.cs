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
using StringConstantsVAGame = ATAP.Utilities.VoiceAttack.Game.StringConstants;


namespace ATAP.Utilities.VoiceAttack.Game {

  public interface IData : ATAP.Utilities.VoiceAttack.IData {
    public bool GameRunning { get; set; }
    public new void Dispose();

  }

  public abstract class Data : ATAP.Utilities.VoiceAttack.Data, IData {
    public bool GameRunning { get; set; }
    public  Data(IConfigurationRoot configurationRoot, dynamic vaProxy) : base(configurationRoot, (object)vaProxy) {

      GameRunning = false;
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
