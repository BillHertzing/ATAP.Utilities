using System.Collections.Generic;
using System.Linq;
using System.Text.RegularExpressions;
using ATAP.Utilities.Philote;
//using AutoMapper.Configuration;
using static ATAP.Utilities.GenerateProgram.GUsingGroupExtensions;
using static ATAP.Utilities.GenerateProgram.GEnumerationMemberExtensions;
using System;
using System.Text;

namespace ATAP.Utilities.GenerateProgram {
  public static partial class GMacroExtensions {
    public static GUsingGroup MUsingGroupForMicrosoftGenericHostInGHHSAndGHBS() {
      var _gUsingGroup = new GUsingGroup("Usings For Microsoft GenericHost in GHHS and GHBS");
      foreach (var gName in new List<string>() {
        "Microsoft.Extensions.Localization","Microsoft.Extensions.Options","Microsoft.Extensions.Configuration","Microsoft.Extensions.Logging",
        "Microsoft.Extensions.Logging.Abstractions", "Microsoft.Extensions.DependencyInjection", "Microsoft.Extensions.Hosting","Microsoft.Extensions.Hosting.Internal"
      }) {
        var gUsing = new GUsing(gName);
        _gUsingGroup.GUsings.Add(gUsing.Philote, gUsing);
      }
      return _gUsingGroup;
    }
    public static GUsingGroup MUsingGroupForSystemGenericHostInGHHSAndGHBS() {
      var _gUsingGroup = new GUsingGroup("Using Group For System in GHHS and GHBS");
      foreach (var gName in new List<string>() {
        "System", "System.Collections.Generic", "System.Threading", "System.Threading.Tasks"
      }) {
        var gUsing = new GUsing(gName);
        _gUsingGroup.GUsings.Add(gUsing.Philote, gUsing);
      }
      return _gUsingGroup;
    }
    public static GUsingGroup MUsingGroupForConsoleMonitorPatternInInterfaces() {
      var _gUsingGroup = new GUsingGroup("Using Group For System in GHHS and GHBS");
      foreach (var gName in new List<string>() {
        "System.Text", 
      }) {
        var gUsing = new GUsing(gName);
        _gUsingGroup.GUsings.Add(gUsing.Philote, gUsing);
      }
      return _gUsingGroup;
    }
    public static GUsingGroup MUsingGroupForStatelessStateMachine() {
      return new GUsingGroup("Usings For Stateless implementation of StateMachine").AddUsing(new List<GUsing>() {
        new GUsing("System.Linq"),
        new GUsing("Stateless"),
        new GUsing("ATAP.Utilities.Stateless"),
      });
    }
  }
}
