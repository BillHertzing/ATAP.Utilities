using System;
using System.Collections.Generic;
using System.Text;
using System.Threading;
using ATAP.Utilities.Philote;

namespace ATAP.Utilities.GenerateProgram {
  public static partial class RenderExtensions {
    public static StringBuilder RenderEnumerationPreambleStringBuilder(this StringBuilder sb, IGEnumeration gEnumeration, StringBuilder indent, string eol, CancellationToken? ct = default) {
      ct?.ThrowIfCancellationRequested();
      if (gEnumeration.IsBitFlags) {
        sb.Append($"{indent}[Flags]{eol}");
      }
      sb.Append($"{indent}{gEnumeration.GVisibility} enum  {gEnumeration.GName}");
      if (gEnumeration.GInheritance != "") {
        sb.Append($" : {gEnumeration.GInheritance} {{ {eol}");
      }
      else {
        sb.Append($"{{{eol}");
      }
      return sb;
    }
    public static IR1Top REnumeration(this IR1Top r1Top, IGEnumeration gEnumeration) {
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

    public static IR1Top REnumeration(this IR1Top r1Top, IEnumerable<IGEnumeration> gEnumerations) {
      foreach (var o in gEnumerations) {
        r1Top.REnumeration(o);
      }
      return r1Top;
    }
    public static IR1Top REnumeration(this IR1Top r1Top, IDictionary<IPhilote<IGEnumeration>, IGEnumeration> gEnumerations) {
      foreach (var kvp in gEnumerations) {
        r1Top.REnumeration(kvp.Value);
      }
      return r1Top;
    }
  }
}
