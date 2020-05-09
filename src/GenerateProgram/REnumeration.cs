using System;
using System.Collections.Generic;
using System.Text;
using System.Threading;
using ATAP.Utilities.Philote;

namespace GenerateProgram {
  public static partial class RenderExtensions {
    public static StringBuilder RenderEnumerationPreambleStringBuilder(this StringBuilder sb, GEnumeration gEnumeration, StringBuilder indent, string eol, CancellationToken? ct = default) {
      ct?.ThrowIfCancellationRequested();
      sb.Append($"{indent}{gEnumeration.GVisibility} enum  {gEnumeration.GName}");
      if (gEnumeration.IsBitFlags) {
        
      }
      else {
        sb.Append($"{gEnumeration.GName}");

      }
      return sb;
    }
    public static IR1Top REnumeration(this IR1Top r1Top, GEnumeration gEnumeration) {
      r1Top.RComment(gEnumeration.GComment);
      r1Top.RAttributeGroup(gEnumeration.GAttributeGroups);
      r1Top.RAttribute(gEnumeration.GAttributes);
      r1Top.Sb.RenderEnumerationPreambleStringBuilder(gEnumeration, r1Top.Indent, r1Top.Eol, r1Top.Ct);
      r1Top.Indent.Append(r1Top.IndentDelta);
      r1Top.REnumerationMember(gEnumeration.GEnumerationMembers);
      r1Top.Indent.ReplaceFirst(r1Top.IndentDelta,"");
      r1Top.Sb.Append($"{r1Top.Indent} }}{r1Top.Eol}");
      return r1Top;
    }

    public static IR1Top REnumeration(this IR1Top r1Top, IEnumerable<GEnumeration> gEnumerations) {
      foreach (var o in gEnumerations) {
        r1Top.REnumeration(o);
      }
      return r1Top;
    }
    public static IR1Top REnumeration(this IR1Top r1Top, Dictionary<Philote<GEnumeration>, GEnumeration> gEnumerations) {
      foreach (var kvp in gEnumerations) {
        r1Top.REnumeration(kvp.Value);
      }
      return r1Top;
    }
  }
}
