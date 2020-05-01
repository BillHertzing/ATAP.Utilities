using System;
using System.Collections.Generic;
using System.Text;
using System.Threading;
using ATAP.Utilities.Philote;
//using Microsoft.FSharp.Core;

namespace GenerateProgram {


  public interface IW1Top
  {
    String BasePath { get; set; }
    Encoding Encoding { get; set; }
    CancellationToken? Ct { get; set; }
    //Dictionary<string, object> Session { get; set; }
    //void Write();
  }

  public class W1Top : IW1Top {//},IW1TopData {
    //public W1Top(string basePath = "", Dictionary<string, object> session = default, Encoding encoding = default, CancellationToken? ct = default) {
    //  Session = session ?? throw new ArgumentNullException(nameof(session));
    public W1Top(string basePath = "", Encoding? encoding = default, CancellationToken? ct = default) {
      BasePath = basePath ?? throw new ArgumentNullException(nameof(basePath));
      Encoding = encoding == default ? Encoding.UTF8 : encoding;
      Ct = ct;
    }

    public String BasePath { get; set; }
    public Encoding Encoding { get; set; }
    public CancellationToken? Ct { get; set; }
    //public Dictionary<string, object> Session { get; set; }
    //public void Write() {
    //  var sk = Session.Keys;
    //  foreach (var key in sk) {
    //    var o = Session[key];
    //    switch (o) {
    //      //case GUsing gUsing:
    //      //  this.WUsing( gUsing);
    //      //  break;
    //      //case List<GUsing> gUsings:
    //      //  foreach (var gu in gUsings) {
    //      //    this.WUsing(gu);
    //      //  }
    //      //  break;
    //      //case GUsingGroup gUsingGroup:
    //      //  this.WUsingGroup( gUsingGroup);
    //      //  break;
    //      //case Dictionary<Philote<GUsingGroup>, GUsingGroup> gUsingGroups:
    //      //  this.WUsingGroup( gUsingGroups);
    //      //  break;
    //      //case GNamespace gNamespace:
    //      //  this.WNamespace( gNamespace);
    //      //  break;
    //      //case GClass gClass:
    //      //  this.WClass( gClass);
    //      //  break;
    //      //case GInterface gInterface:
    //      //  this.WInterface( gInterface);
    //      //  break;
    //      //case GProperty gProperty:
    //      //  this.WProperty( gProperty);
    //      //  break;
    //      //case GMethod gMethod:
    //      //  this.WMethod( gMethod);
    //      //  break;
    //      case GCompilationUnit gCompilationUnit:
    //        this.WCompilationUnit(gCompilationUnit);
    //        break;
         
    //      default:
    //        throw new NotImplementedException(string.Format("object at key {0} is of unknown type {1}", key,
    //          typeof(object)));
    //    }
    //  }
    //}
  }
}
