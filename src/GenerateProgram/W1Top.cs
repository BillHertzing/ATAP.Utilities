using System;
using System.Collections.Generic;
using System.Diagnostics.Eventing.Reader;
using System.IO;
using System.Linq.Expressions;
using System.Text;
using System.Threading;
using ATAP.Utilities.Philote;
//using Microsoft.FSharp.Core;

namespace GenerateProgram {


  public interface IW1Top {
    String BasePath { get; set; }
    Encoding Encoding { get;  }
    bool? Force { get; }

    CancellationToken? Ct { get;  }
    //Dictionary<string, object> Session { get; set; }
    //void Write();
  }

  public class W1Top : IW1Top {//},IW1TopData {
    //public W1Top(string basePath = "", Dictionary<string, object> session = default, Encoding encoding = default, CancellationToken? ct = default) {
    //  Session = session ?? throw new ArgumentNullException(nameof(session));
    public W1Top(string basePath = "", Encoding? encoding = default, bool? force = default,
      CancellationToken? ct = default) {
      BasePath = basePath ?? throw new ArgumentNullException(nameof(basePath));
      Encoding = encoding == default ? Encoding.UTF8 : encoding;
      Force = force == default ? false : force;
      Ct = ct;
     
      var dirInfo = new DirectoryInfo(BasePath);
      if (!dirInfo.Exists) {

        if (!(bool)Force) {
          //ToDo: Log exception
          throw new Exception(message: $"Base directory for Generated code does not exist (try force=true): {BasePath}");
        }
        else {
          try {
            dirInfo.Create();
          }
          catch (System.IO.IOException e) {
            //ToDo: Log exception
            throw new Exception(message: $"Could Not create base directory for Generated code: {BasePath}", innerException: e);
          }
        }
      }
    }

    public String BasePath { get; set; }
    public Encoding Encoding { get; set; }
    public bool? Force { get; set; }
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
