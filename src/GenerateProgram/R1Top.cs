using System;
using System.Collections.Generic;
using System.Text;
using System.Threading;
using ATAP.Utilities.Philote;

namespace GenerateProgram {
  public interface IR1TopData {
    StringBuilder Indent { get; set; }
    string IndentDelta { get; set; }
    string Eol { get; set; }
    CancellationToken? Ct { get; set; }
  }

  public class R1TopData : IR1TopData {
    public R1TopData(StringBuilder indent, string indentDelta, string eol, CancellationToken ct = default) {
      Indent = indent ?? throw new ArgumentNullException(nameof(indent));
      IndentDelta = indentDelta ?? throw new ArgumentNullException(nameof(indentDelta));
      Eol = eol ?? throw new ArgumentNullException(nameof(eol));
      Ct = ct;
    }

    public StringBuilder Indent { get; set; }
    public string IndentDelta { get; set; }
    public string Eol { get; set; }
    public CancellationToken? Ct { get; set; }
  }

  public interface IR1Top {
    Dictionary<string, object> Session { get; set; }
    IR1TopData R1TopData { get; set; }
    StringBuilder Sb { get; set; }
    void Render(IW1Top w1Top);
  }

  public class R1Top : IR1Top {

    public R1Top(Dictionary<string, object> session, IR1TopData r1TopData, StringBuilder sb) {
      Session = session ?? throw new ArgumentNullException(nameof(session));
      R1TopData = r1TopData ?? throw new ArgumentNullException(nameof(r1TopData));
      Sb = sb ?? throw new ArgumentNullException(nameof(sb));
    }

    public Dictionary<string, object> Session { get; set; }
    public IR1TopData R1TopData { get; set; }
    public StringBuilder Sb { get; set; }

    public void Render(IW1Top w1Top) {
      var sk = Session.Keys;
      foreach (var key in sk) {
        var o = Session[key];
        switch (o) {
          case GUsing gUsing:
            this.RUsing(gUsing);
            break;
          case List<GUsing> gUsings:
            foreach (var gu in gUsings) {
              this.RUsing(gu);
            }
            break;
          case GUsingGroup gUsingGroup:
            this.RUsingGroup(gUsingGroup);
            break;
          case Dictionary<Philote<GUsingGroup>, GUsingGroup> gUsingGroups:
            this.RUsingGroup(gUsingGroups);
            break;
          case GNamespace gNamespace:
            this.RNamespace(gNamespace);
            break;
          case GClass gClass:
            this.RClass(gClass);
            break;
          case GInterface gInterface:
            this.RInterface(gInterface);
            break;
          case GProperty gProperty:
            this.RProperty(gProperty);
            break;
          case GMethod gMethod:
            this.RMethod(gMethod);
            break;
          case GCompilationUnit gCompilationUnit:
            this.RCompilationUnit(gCompilationUnit, w1Top);
            break;
          case Dictionary<Philote<GCompilationUnit>, GCompilationUnit> gCompilationUnits:
            this.RCompilationUnit(gCompilationUnits, w1Top);
            break;
          case GAssemblyUnit gAssemblyUnit:
            this.RAssemblyUnit(gAssemblyUnit, w1Top);
            break;
          case Dictionary<Philote<GAssemblyUnit>, GAssemblyUnit> gAssemblyUnits:
            this.RAssemblyUnit(gAssemblyUnits, w1Top);
            break;
          default:
            throw new NotImplementedException(string.Format("object at key {0} is of unknown type {1}", key,
              typeof(object)));
        }
      }
    }
  }
}
