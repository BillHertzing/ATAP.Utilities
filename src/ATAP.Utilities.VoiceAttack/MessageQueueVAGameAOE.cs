using System;

using Serilog;

//using Microsoft.Extensions.Logging;
//using Microsoft.Extensions.Logging.Abstractions;

using ATAP.Utilities.MessageQueue;

namespace ATAP.Utilities.VoiceAttack.Game.AOE {


  public interface ISendMessageResults : ISendMessageResultsAbstract { }
  public class SendMessageResults : ISendMessageResults {
    public bool Success { get; set; }

    public SendMessageResults() : this(false) { }
    public SendMessageResults(bool success) {
      Success = success;
    }
  }

}
