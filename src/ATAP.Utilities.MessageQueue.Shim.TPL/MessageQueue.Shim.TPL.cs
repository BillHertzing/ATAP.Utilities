using System;
using System.Collections.Generic;
using System.Threading;

using Microsoft.Extensions.Configuration;

using ATAP.Utilities.MessageQueue;
using Polly;

using System.Threading.Tasks.Dataflow;


using Serilog;

namespace ATAP.Utilities.MessageQueue.Shim.TPL {

  public class TPLMessageQueue<TSendMessageResults> : MessageQueueAbstract<TSendMessageResults> where TSendMessageResults : ISendMessageResultsAbstract, new() {

public IConfigurationRoot ConfigurationRoot { get; set; }
    private ActionBlock<Byte[]> Messages { get; set; }

    public TPLMessageQueue(Action<Byte[]> receiveAction) : this(receiveAction, null) { }
    public TPLMessageQueue(Action<Byte[]> receiveAction, CancellationToken? cancellationToken) : base(receiveAction, cancellationToken) {
      Messages = new ActionBlock<Byte[]>((message) => {
        // ToDO: Wrap in try catch and/or  Polly
        ReceiveAction.Invoke(message);
      });
    }
    public TPLMessageQueue(IConfigurationRoot? configurationRoot, Action<Byte[]> receiveAction, CancellationToken? cancellationToken) : base(receiveAction, cancellationToken) {
      ConfigurationRoot = configurationRoot;
      Messages = new ActionBlock<Byte[]>((message) => {
        // ToDO: Wrap in try catch and/or  Polly
        ReceiveAction.Invoke(message);
      });
    }

    public TSendMessageResults SendMessage(Byte[] message) {
      if (message == null) { throw new ArgumentNullException(nameof(message)); }
      Messages.Post(message);
      //Serilog.Log.Debug("{0} {1}: Message sent {2}", "Message.Queue.Shim.TPL", "SendMessage", message);
      return new TSendMessageResults() { Success = true };  // Simple TPL Action Block as Message Queue has nothing to return // Later bindings will return at least the ack for more sophisticated messagequeue
    }

    // public void ExecuteReceiveMessageAction(Byte[] message) {
    //   // Wrap in try catch and/or  Polly
    //   base.ReceiveAction.Invoke(message);
    // }

    // ToDo: add a Configure which has default values of the TPLMessageQueueOptionsCurrent should come from an IConfiguration object, and keys/default values should come from a StringConstants
    // ToDo: ConvertOptions should be expanded to include a set of extensions for TPLMessageQueueOptions class to promote reuse of the instance

    #region IDisposable Support
    private bool disposedValue = false; // To detect redundant calls
    protected new virtual void Dispose(bool disposing) {
      if (!disposedValue) {
        if (disposing) {
          Messages.Complete();
          // Dispose of downlevel
          base.Dispose();
        }
        disposedValue = true;
      }
    }
    // This code added to correctly implement the disposable pattern.
    public new void Dispose() {
      // Do not change this code. Put cleanup code in Dispose(bool disposing) above.
      Dispose(true);
    }
    #endregion

  }
}

