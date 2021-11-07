using System;

using Serilog;
using AutoMapper;

//using Microsoft.Extensions.Logging;
//using Microsoft.Extensions.Logging.Abstractions;

using CollectionExtensions = ATAP.Utilities.Collection.Extensions;
using System.Text.Json;

namespace ATAP.Utilities.VoiceAttack.Game.AOE {

  public interface IVoiceAttackActionAbstract {
    VoiceAttackActionKind VoiceAttackActionKind { get; set; }
  }

  public abstract class VoiceAttackActionAbstract : IVoiceAttackActionAbstract {
    public VoiceAttackActionKind VoiceAttackActionKind { get; set; }
    public VoiceAttackActionAbstract(VoiceAttackActionKind voiceAttackActionKind) {
      VoiceAttackActionKind = voiceAttackActionKind;
    }
  }

  public interface IVoiceAttackActionSay {
    public string Phrase { get; set; }
  }

  public class VoiceAttackActionSay : VoiceAttackActionAbstract, IVoiceAttackActionSay {
    public string Phrase { get; set; }
    public VoiceAttackActionSay(string phrase) : base(VoiceAttackActionKind.Say) {
      Phrase = phrase;
    }
  }

  public interface IVoiceAttackActionCommand {
    public string Command { get; set; }
  }

  public class VoiceAttackActionCommand : VoiceAttackActionAbstract, IVoiceAttackActionCommand {
    public string Command { get; set; }
    public VoiceAttackActionCommand(string command) : base(VoiceAttackActionKind.Command) {
      Command = command;
    }
  }

  public enum VoiceAttackActionKind {
    Say,
    Delay,
    Command

  }

  public interface IVoiceAttackActionWithDelay {
    public TimeSpanDto? PreActionDelay { get; set; }
    public IVoiceAttackActionAbstract VoiceAttackAction { get; set; }
    public TimeSpanDto? PostActionDelay { get; set; }
  }

  public class VoiceAttackActionWithDelay : IVoiceAttackActionWithDelay {
    public TimeSpanDto? PreActionDelay { get; set; }
    public IVoiceAttackActionAbstract VoiceAttackAction { get; set; }
    public TimeSpanDto? PostActionDelay { get; set; }
    public VoiceAttackActionWithDelay(TimeSpan? preActionDelay, IVoiceAttackActionAbstract voiceAttackAction, TimeSpan? postActionDelay) {
      PreActionDelay = new() { TotalMilliseconds = 1000 };//{TotalMilliseconds =  preActionDelay.TotalMilliseconds }; //Data.Mapper.Map<TimeSpanDto>(preActionDelay);
      VoiceAttackAction = voiceAttackAction;
      PostActionDelay = new(){ TotalMilliseconds = 1000 }; // {TotalMilliseconds =  postActionDelay.TotalMilliseconds };; //Data.Mapper.Map<TimeSpanDto>(postActionDelay);
    }
  }

  public class TimeSpanDto {
    public double TotalMilliseconds { get; set; }
  }
}

