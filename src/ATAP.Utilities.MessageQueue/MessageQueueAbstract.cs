using System;
using System.Collections.Generic;
using System.Threading;
#if NETDESKTOP
using System.ComponentModel;
#endif

namespace ATAP.Utilities.MessageQueue {

  public abstract class MessageQueueOptionsAbstract : IMessageQueueOptions { }

  // public abstract class SetupMessageQueueResultsAbstract : ISetupMessageQueueResultsAbstract {
  //   public bool Success { get; set; }

  //   protected SetupMessageQueueResultsAbstract() : this(false) {
  //   }

  //   protected SetupMessageQueueResultsAbstract(bool success) {
  //     Success = success;
  //   }
  // }

  public abstract class SendMessageResultsAbstract : ISendMessageResultsAbstract {
    public bool Success { get; set; }

    public SendMessageResultsAbstract() : this(false) {
    }

    public SendMessageResultsAbstract(bool success) {
      Success = success;
    }
  }

//ToDo: write a fluent builder for create a MessageQueueObject
  public class MessageQueueBuilderAbstract //: IMessageQueueBuilderAbstract
  {
  }

  public abstract class MessageQueueAbstract<TSendMessageResults> : IMessageQueueAbstract<TSendMessageResults> where TSendMessageResults : ISendMessageResultsAbstract {
    public IMessageQueueOptions MessageQueueOptions { get; set; }
    public CancellationToken? CancellationToken { get; set; }
    public Func<Byte[], TSendMessageResults> SendFunc { get; set; }
    //public Func<IEnumerable<IEnumerable<Byte[]>>, TSendMessageResults> SendEnumerableFunc { get; set; }
    //public Func<IDictionary<string, IEnumerable<Byte[]>>, TSendMessageResults> SendDictionaryFunc { get; set; }

    protected Action<Byte[]> ReceiveAction { get; set; }
    //private Action<IEnumerable<Byte[]>> ReceiveEnumerableAction { get; set; }
    //private Action<IDictionary<string, IEnumerable<Byte[]>>> ReceiveDictionaryAction { get; set; }

    public MessageQueueAbstract(Action<Byte[]> receiveAction, CancellationToken? cancellationToken) {
      if (receiveAction == null ) {throw new NullReferenceException(nameof(receiveAction));}
      ReceiveAction = receiveAction;
      if (cancellationToken != null) {
        CancellationToken = cancellationToken;
      }
      else {
        CancellationToken = null;
      }
    }

    #region IDisposable Support
    private bool disposedValue = false; // To detect redundant calls
    protected virtual void Dispose(bool disposing) {
      if (!disposedValue) {
        if (disposing) {
          // dispose of anything needing disposing
        }
      }
      disposedValue = true;
    }
    // This code added to correctly implement the disposable pattern.
    public void Dispose() {
      // Do not change this code. Put cleanup code in Dispose(bool disposing) above.
      Dispose(true);
    }
    #endregion

    //public ISetupMessageQueueResultsAbstract SetupMessageQueue() : this(null, null) {    }

    // public SetupMessageQueue(Action<Byte[]> receiveAction, CancellationToken? cancellationToken) {
    //   if (receiveAction == null ) {throw new argumentNullException(nameof(receiveAction));}
    //   ReceiveAction = receiveAction;
    //   if (cancellationToken != null) {
    //     CancellationToken = cancellationToken;
    //   }
    //   else {
    //     CancellationToken = null;
    //   }
    // }

  }
  #region Support public init only setters on Net Desktop runtime
#if NETDESKTOP
// Add IsExternalInit if the TargetFramework is a Net Desktop runtime
namespace System.Runtime.CompilerServices {
  [EditorBrowsable(EditorBrowsableState.Never)]
  internal static class IsExternalInit { }
}
#endif
#endregion

}
