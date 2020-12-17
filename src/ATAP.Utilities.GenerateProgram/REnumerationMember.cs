using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading;
using ATAP.Utilities.Philote;

namespace ATAP.Utilities.GenerateProgram {
  public static partial class RenderExtensions {
    public static StringBuilder RenderEnumerationMemberStringBuilder(this StringBuilder sb,
      IGEnumerationMember gEnumerationMember, StringBuilder indent, string eol, CancellationToken? ct = default) {
      ct?.ThrowIfCancellationRequested();
      sb.Append($"{indent}{gEnumerationMember.GName} ");
      if (gEnumerationMember.GValue != null) {
        sb.Append($" = {gEnumerationMember.GValue.ToString()},{eol}");
      }
      else {
        sb.Append($",{eol}");
      }
      return sb;
    }
    public static IR1Top REnumerationMember(this IR1Top r1Top, IGEnumerationMember gEnumerationMember) {
      r1Top.RComment(gEnumerationMember.GComment);
      r1Top.RAttributeGroup(gEnumerationMember.GAttributeGroups);
      r1Top.RAttribute(gEnumerationMember.GAttributes);
      r1Top.Sb.RenderEnumerationMemberStringBuilder(gEnumerationMember, r1Top.Indent, r1Top.Eol, r1Top.Ct);
      return r1Top;
    }
    public static IR1Top REnumerationMember(this IR1Top r1Top, IEnumerable<IGEnumerationMember> gEnumerationMembers) {
      foreach (var o in gEnumerationMembers) {
        r1Top.REnumerationMember(o);
      }
      return r1Top;
    }
    public static IR1Top REnumerationMember(this IR1Top r1Top,
      IDictionary<IPhilote<IGEnumerationMember>, IGEnumerationMember> gEnumerationMembers) {
      foreach (var kvp in gEnumerationMembers) {
        r1Top.REnumerationMember(kvp.Value);
      }
      return r1Top;
    }
  }
}
