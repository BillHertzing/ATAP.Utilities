using System;
using System.Collections;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading;
using System.Threading.Tasks;
using ATAP.Utilities.Philote;
using GenerateProgram;

namespace GenerateProgram
{
  public static  partial class GCompilationUnitExtensions
  {
    public static GCompilationUnit CompilationUnitStringConstants(this GCompilationUnit gCompilationUnit, String gNamespaceName) {
      GClass gClass = new GClass("StringConstants",gVisibility:"public","static");
      GConstStringGroup gConstStringGroup = new GConstStringGroup(gName:"Settings File Names");
      foreach (var kvp in new Dictionary<string,string>() {
        {"SettingsFileName","AssemblyNameTemplateReplacementPattern"},
        {"SettingsFileNameSuffix","json"},
      }) {
        GConstString gConstString = new GConstString(kvp.Key,kvp.Value);
        gConstStringGroup.GConstStrings[gConstString.Philote] = gConstString;
      }
      gClass.GConstStringGroups[gConstStringGroup.Philote] = gConstStringGroup;
      gConstStringGroup = new GConstStringGroup(gName:"Temporary File Names");
      foreach (var kvp in new Dictionary<string,string>() {
        {"TemporaryDirectoryBaseConfigRootKey","TemporaryDirectoryBase"},
        {"TemporaryDirectoryBaseDefault","D:/Temp/AssemblyNameTemplateReplacementPattern/"},
      }) {
        GConstString gConstString = new GConstString(kvp.Key,kvp.Value);
        gConstStringGroup.GConstStrings[gConstString.Philote] = gConstString;
      }
      gClass.GConstStringGroups[gConstStringGroup.Philote] = gConstStringGroup;
      GNamespace gNamespace = new GNamespace(gNamespaceName);
      gNamespace.GClasss[gClass.Philote] = gClass;
      GCompilationUnit newgCompilationUnit = new GCompilationUnit(gName:"StringConstants");
      newgCompilationUnit.GNamespaces[gNamespace.Philote] = (gNamespace);
      return newgCompilationUnit;
    }
    
  }
}
