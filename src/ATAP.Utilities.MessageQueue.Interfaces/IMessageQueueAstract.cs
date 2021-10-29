using System;
using System.Collections.Generic;
using System.Threading;

namespace ATAP.Utilities.MessageQueue {
  public interface IMessageQueueOptions {}

  public interface IMessageQueueAbstract<out TSendMessageResults>  where TSendMessageResults : ISendMessageResultsAbstract {

     CancellationToken? CancellationToken { get; init; }

    Func<Byte[], TSendMessageResults> SendFunc { get; }
    //Func<IEnumerable<IEnumerable<Byte[]>>, TSendMessageResults> SendEnumerableFunc { get; }
    //Func<IDictionary<string, IEnumerable<Byte[]>>, TSendMessageResults> SendDictionaryFunc { get; }

    public new void Dispose();

  }
}
