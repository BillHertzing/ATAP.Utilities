using System;
using System.Collections.Generic;
using System.Text;
using System.Threading;
using ATAP.Utilities.Philote;

namespace ATAP.Utilities.GenerateProgram {
  public static partial class RenderExtensions {
    public static IR1Top RDelegate(this IR1Top r1Top, IGDelegate gDelegate) {
      r1Top.RComment(gDelegate.GComment);
      r1Top.RDelegateDeclaration(gDelegate.GDelegateDeclaration);
      return r1Top;
    }

    public static IR1Top RDelegate(this IR1Top r1Top, IEnumerable<IGDelegate> gDelegates) {
      foreach (var o in gDelegates) {
        r1Top.RDelegate(o);
      }
      return r1Top;
    }
    public static IR1Top RDelegate(this IR1Top r1Top, IDictionary<IPhilote<IGDelegate>, IGDelegate> gDelegates) {
      foreach (var kvp in gDelegates) {
        r1Top.RDelegate(kvp.Value);
      }
      return r1Top;
    }
  }
}
