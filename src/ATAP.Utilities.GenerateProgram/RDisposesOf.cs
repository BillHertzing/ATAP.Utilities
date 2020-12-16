using System.Collections.Generic;
using System.Text;
using System.Threading;
using ATAP.Utilities.Philote;

namespace ATAP.Utilities.GenerateProgram {
  public static partial class RenderExtensions {
 
    public static StringBuilder RenderDisposesOfPreambleStringBuilder(this StringBuilder sb, List<string> gDisposesOf, StringBuilder indent, string indentDelta, string eol, CancellationToken? ct = default) {
      ct?.ThrowIfCancellationRequested();
      sb.Append($"{indent}private bool _disposedValue = false; // To detect redundant calls{eol}");
      sb.Append($"{indent}protected virtual void Dispose(bool disposing) {{{eol}");
      sb.Append($"{indent}{indentDelta}if (!_disposedValue) {{{eol}");
      sb.Append($"{indent}{indentDelta}{indentDelta}if (disposing) {{{eol}");
      foreach (var o in gDisposesOf) {
        sb.Append($"{indent}{indentDelta}{indentDelta}{indentDelta}if ({o} != null) {{{eol}");
        sb.Append($"{indent}{indentDelta}{indentDelta}{indentDelta}{indentDelta}{o}.Dispose();{eol}");
        sb.Append($"{indent}{indentDelta}{indentDelta}{indentDelta}}}{eol}");
      }
      //sb.RenderDisposesOfItemsStringBuilder(gDisposesOf,indent, indentDelta,eol);
      sb.Append($"{indent}{indentDelta}{indentDelta}}}{eol}");
      sb.Append($"{indent}{indentDelta}_disposedValue = true;{eol}");
      sb.Append($"{indent}{indentDelta}}}{eol}");
      sb.Append($"{indent}}}{eol}");
      sb.Append($"{indent}public void Dispose() {{{eol}");
      sb.Append($"{indent}{indentDelta}Dispose(true);{eol}");
      sb.Append($"{indent}}}{eol}");
      return sb;
    }
    public static IR1Top RDisposesOf(this IR1Top r1Top, List<string> gDisposesOf) {
      r1Top.Sb.RenderDisposesOfPreambleStringBuilder(gDisposesOf, r1Top.Indent, r1Top.IndentDelta,r1Top.Eol, r1Top.Ct);
      return r1Top;
    }
    
  }
}
