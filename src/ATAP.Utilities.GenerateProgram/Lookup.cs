using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace ATAP.Utilities.GenerateProgram {
  public static class Lookup {
    public static (
      IEnumerable<GAssemblyUnit> gAssemblyUnits,
      IEnumerable<GCompilationUnit> gCompilationUnits,
      IEnumerable<GNamespace> gNamespacess,
      IEnumerable<GClass> gClasss,
      IEnumerable<GMethod> gMethods)
      LookupPrimaryConstructorMethod(
        IEnumerable<GAssemblyGroup> gAssemblyGroups,
        string gAssemblyGroupName = "",
        string gAssemblyUnitName = "",
        string gCompilationUnitName = "",
        string gNamespaceName = "",
        string gClassName = ""
      ) {
      List<GAssemblyUnit> gAssemblyUnits = new List<GAssemblyUnit>();
      List<GCompilationUnit> gCompilationUnits = new List<GCompilationUnit>();
      List<GNamespace> gNamespaces = new List<GNamespace>();
      List<GClass> gClasss = new List<GClass>();
      List<GMethod> gMethods = new List<GMethod>();
      foreach (var gAg in gAssemblyGroups) {
        if (String.IsNullOrWhiteSpace(gAssemblyGroupName) || gAg.GName == gAssemblyGroupName) {
          foreach (var gAU in gAg.GAssemblyUnits) {
            if (String.IsNullOrWhiteSpace(gAssemblyUnitName) || gAU.Value.GName == gAssemblyUnitName) {
              foreach (var gCU in gAU.Value.GCompilationUnits) {
                if (String.IsNullOrWhiteSpace(gCompilationUnitName) || gCU.Value.GName == gCompilationUnitName) {
                  foreach (var gNs in gCU.Value.GNamespaces) {
                    if (String.IsNullOrWhiteSpace(gNamespaceName) || gNs.Value.GName == gNamespaceName) {
                      foreach (var gCl in gNs.Value.GClasss) {
                        if (String.IsNullOrWhiteSpace(gClassName) || gCl.Value.GName == gClassName) {
                          foreach (var gMe in gCl.Value.CombinedMethods()) {
                            if (gMe.GDeclaration.IsConstructor) {
                              gAssemblyUnits.Add(gAU.Value);
                              gCompilationUnits.Add(gCU.Value);
                              gNamespaces.Add(gNs.Value);
                              gClasss.Add(gCl.Value);
                              gMethods.Add(gMe);
                            }
                          }
                        }
                      }
                    }
                  }
                }
              }
            }
          }
        }
      }
      return (gAssemblyUnits, gCompilationUnits, gNamespaces, gClasss, gMethods);
    }
    public static (
      IEnumerable<GAssemblyUnit> gAssemblyUnits,
      IEnumerable<GCompilationUnit> gCompilationUnits,
      IEnumerable<GNamespace> gNamespacess,
      IEnumerable<GClass> gClasss)
      LookupDerivedClass(
        IEnumerable<GAssemblyGroup> gAssemblyGroups,
        string gAssemblyGroupName = "",
        string gAssemblyUnitName = "",
        string gCompilationUnitName = "",
        string gNamespaceName = "",
        string gClassName = ""
      ) {
      List<GAssemblyUnit> gAssemblyUnits = new List<GAssemblyUnit>();
      List<GCompilationUnit> gCompilationUnits = new List<GCompilationUnit>();
      List<GNamespace> gNamespaces = new List<GNamespace>();
      List<GClass> gClasss = new List<GClass>();
      List<GMethod> gMethods = new List<GMethod>();
      foreach (var gAg in gAssemblyGroups) {
        if (String.IsNullOrWhiteSpace(gAssemblyGroupName) || gAg.GName == gAssemblyGroupName) {
          foreach (var gAU in gAg.GAssemblyUnits) {
            if (String.IsNullOrWhiteSpace(gAssemblyUnitName) || gAU.Value.GName == gAssemblyUnitName) {
              foreach (var gCU in gAU.Value.GCompilationUnits) {
                if (String.IsNullOrWhiteSpace(gCompilationUnitName) || gCU.Value.GName == gCompilationUnitName) {
                  foreach (var gNs in gCU.Value.GNamespaces) {
                    if (String.IsNullOrWhiteSpace(gNamespaceName) || gNs.Value.GName == gNamespaceName) {
                      foreach (var gCl in gNs.Value.GClasss) {
                        if (String.IsNullOrWhiteSpace(gClassName) || gCl.Value.GName == gClassName) {
                          gAssemblyUnits.Add(gAU.Value);
                          gCompilationUnits.Add(gCU.Value);
                          gNamespaces.Add(gNs.Value);
                          gClasss.Add(gCl.Value);
                        }
                      }
                    }
                  }
                }
              }
            }
          }
        }
      }
      return (gAssemblyUnits, gCompilationUnits, gNamespaces, gClasss);
    }
    public static (
      IEnumerable<GAssemblyUnit> gAssemblyUnits,
      IEnumerable<GCompilationUnit> gCompilationUnits,
      IEnumerable<GNamespace> gNamespacess,
      IEnumerable<GInterface> gInterfaces
      )
      LookupInterfaces(
        IEnumerable<GAssemblyGroup> gAssemblyGroups,
        string gAssemblyGroupName = "",
        string gAssemblyUnitName = "",
        string gCompilationUnitName = "",
        string gNamespaceName = "",
        string gInterfaceName = ""
      ) {
      List<GAssemblyUnit> gAssemblyUnits = new List<GAssemblyUnit>();
      List<GCompilationUnit> gCompilationUnits = new List<GCompilationUnit>();
      List<GNamespace> gNamespaces = new List<GNamespace>();
      List<GInterface> gInterfaces = new List<GInterface>();
      foreach (var gAg in gAssemblyGroups) {
        if (String.IsNullOrWhiteSpace(gAssemblyGroupName) || gAg.GName == gAssemblyGroupName) {
          foreach (var gAU in gAg.GAssemblyUnits) {
            if (String.IsNullOrWhiteSpace(gAssemblyUnitName) || gAU.Value.GName == gAssemblyUnitName) {
              foreach (var gCU in gAU.Value.GCompilationUnits) {
                if (String.IsNullOrWhiteSpace(gCompilationUnitName) || gCU.Value.GName == gCompilationUnitName) {
                  foreach (var gNs in gCU.Value.GNamespaces) {
                    if (String.IsNullOrWhiteSpace(gNamespaceName) || gNs.Value.GName == gNamespaceName) {
                      foreach (var gIn in gNs.Value.GInterfaces) {
                        if (String.IsNullOrWhiteSpace(gInterfaceName) || gIn.Value.GName == gInterfaceName) {
                          gAssemblyUnits.Add(gAU.Value);
                          gCompilationUnits.Add(gCU.Value);
                          gNamespaces.Add(gNs.Value);
                          gInterfaces.Add(gIn.Value);
                        }
                      }
                    }
                  }
                }
              }
            }
          }
        }
      }
      return (gAssemblyUnits, gCompilationUnits, gNamespaces, gInterfaces);
    }
    public static (
      IEnumerable<GAssemblyUnit> gAssemblyUnits,
      IEnumerable<GProjectUnit> gProjectUnits
      )
    LookupProjectUnits(
      IEnumerable<GAssemblyGroup> gAssemblyGroups,
      string gAssemblyGroupName = "",
      string gAssemblyUnitName = "",
      string gProjectUnitName = ""
    ) {
      List<GAssemblyUnit> gAssemblyUnits = new List<GAssemblyUnit>();
      List<GProjectUnit> gProjectUnits = new List<GProjectUnit>();
      foreach (var gAg in gAssemblyGroups) {
        if (String.IsNullOrWhiteSpace(gAssemblyGroupName) || gAg.GName == gAssemblyGroupName) {
          foreach (var gAU in gAg.GAssemblyUnits) {
            if (String.IsNullOrWhiteSpace(gAssemblyUnitName) || gAU.Value.GName == gAssemblyUnitName) {
              gAssemblyUnits.Add(gAU.Value);
              gProjectUnits.Add(gAU.Value.GProjectUnit);
            }
          }
        }
      }
      return (gAssemblyUnits, gProjectUnits);
    }
  }
}
