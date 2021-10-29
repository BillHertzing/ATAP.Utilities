using System;
using System.Collections.Generic;
using System.Threading;

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
    public IMessageQueueOptions MessageQueueOptions { get; init; }
    public CancellationToken? CancellationToken { get; init; }
    public Func<Byte[], TSendMessageResults> SendFunc { get; init; }
    //public Func<IEnumerable<IEnumerable<Byte[]>>, TSendMessageResults> SendEnumerableFunc { get; init; }
    //public Func<IDictionary<string, IEnumerable<Byte[]>>, TSendMessageResults> SendDictionaryFunc { get; init; }

    protected Action<Byte[]> ReceiveAction { get; init; }
    //private Action<IEnumerable<Byte[]>> ReceiveEnumerableAction { get; init; }
    //private Action<IDictionary<string, IEnumerable<Byte[]>>> ReceiveDictionaryAction { get; init; }

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
    protected new virtual void Dispose(bool disposing) {
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
}
