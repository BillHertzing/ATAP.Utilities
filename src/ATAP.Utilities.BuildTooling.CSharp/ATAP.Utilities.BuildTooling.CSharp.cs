using System;
using System.IO;
using System.Text;
using System.Text.RegularExpressions;
using Microsoft.Build.Framework;
using Microsoft.Build.Utilities;

namespace ATAP.Utilities.BuildTooling {
  /// <summary>
  /// The static class Utilities contains the majority of the executable code. It is possible for one static function to refer to another static function.
  /// however, it is not possible for a class that derives from Task to call another Task-derived function. if you attempt to call an Execute method on a Task class, it produces a run-time error that the Task has not been initialized.
  /// So the design philosophy is to have each Task-derived class call into a static function of the same name.
  /// That way, for example, the Task UpdateVersion calls the static method UpdateVersion which in turn calls the two static functions GetVersion and SetVersion.
  /// </summary>
  public static class Utilities {
      const string labelReleaseCandidate = "RC";
      const string labelStringFormat = "D3";
      const string lifeCycleStageProduction = "Production";
      const string patchStringFormat = "D2";

      const string rePackageVersion = @"(?<Major>\d+)\.(?<Minor>\d+)\.(?<Patch>\d+)(?<isNotPublicReleasePackage>-(?<Label>[^-]+)-(?<LabelCount>[\d]+)){0,1}";
      const string strReAssemblyFileVersion = @"\[assembly\:\s*AssemblyFileVersion(?:Attribute)*\(""\s*(?<MajorVersion>\d+)\.(?<MinorVersion>\d+)\.(?<Build>.+)\.(?<Revision>\d+)\s*""\s*\)";
      const string strReAssemblyInformationalVersion = @"\[assembly\:\s*AssemblyInformationalVersion(?:Attribute)*\(""\s*(?<PackageVersion>.+)\s*""\s*\)";
      const string strReAssemblyVersion = @"\[assembly\:\s*AssemblyVersion(?:Attribute)*\(""\s*(?<MajorVersion>\d+)\.(?<MinorVersion>\d+)\.(?<PatchVersion>\d+).*""\s*\)";

    /// <summary>
    /// Read versionFile and return the current values of the out parameters
    /// aTAPBuildToolingConfiguration and aTAPBuildToolingDebugVerbosity control the amount of logging to perform when the function is called
    /// log is a logger object
    /// </summary>
    /// <param name="log">an ILog object</param>
    /// <param name="versionFile">full path to a file containing assembly information</param>
    /// <param name="aTAPBuildToolingConfiguration"></param>
    /// <param name="aTAPBuildToolingDebugVerbosity"></param>
    /// <param name="build"></param>
    /// <param name="majorVersion"></param>
    /// <param name="minorVersion"></param>
    /// <param name="patchVersion"></param>
    /// <param name="packageVersion"></param>
    /// <param name="revision"></param>
    public static bool GetVersion(TaskLoggingHelper log, string versionFile, string aTAPBuildToolingConfiguration, string aTAPBuildToolingDebugVerbosity, out int? build, out int? majorVersion, out int? minorVersion, out int? patchVersion, out string packageVersion, out int? revision) {
          // Log the method entry if Debug and Trace
          if(string.Equals(aTAPBuildToolingConfiguration, "Debug", StringComparison.OrdinalIgnoreCase)
              && string.Equals(aTAPBuildToolingDebugVerbosity, "Trace", StringComparison.OrdinalIgnoreCase)) {
              log.LogMessage($"Starting GetVersion, VersionFile = {versionFile}");
          }
          // Initialize output parameter values
          build = null;
          majorVersion = null;
          minorVersion = null;
          patchVersion = null;
          packageVersion = string.Empty;
          revision = null;
          // Compiled regular expression patterns to match for the version information pieces
          Regex REAssemblyVersion = new Regex(strReAssemblyVersion, RegexOptions.IgnoreCase);
          Regex REAssemblyFileVersion = new Regex(strReAssemblyFileVersion, RegexOptions.IgnoreCase);
          Regex REAssemblyInformationalVersion = new Regex(strReAssemblyInformationalVersion, RegexOptions.IgnoreCase);

          FileInfo versionFileInfo = new FileInfo(versionFile);

          if(!versionFileInfo.Exists) {
              log.LogWarning(versionFileInfo.FullName + " does not exist");
              return false;
          }
          string path = versionFileInfo.FullName;
          string text = File.ReadAllText(path);
          MatchCollection matchesAssemblyInformationalVersion = REAssemblyInformationalVersion.Matches(text);
          MatchCollection matchesAssemblyVersion = REAssemblyVersion.Matches(text);
          MatchCollection matchesAssemblyFileVersion = REAssemblyFileVersion.Matches(text);
          if((matchesAssemblyVersion.Count == 0) || (matchesAssemblyFileVersion.Count == 0)
              || (matchesAssemblyInformationalVersion.Count == 0)) {
              log.LogWarning($"GetVersion: Error parsing VersionFile {versionFileInfo.FullName}; matchesAssemblyVersion.Count = {matchesAssemblyVersion.Count}; matchesAssemblyFileVersion.Count = {matchesAssemblyFileVersion.Count}; matchesAssemblyInformationalVersion.Count = {matchesAssemblyInformationalVersion.Count}");
              return false;
          }
          foreach(Match match in matchesAssemblyVersion) {
              GroupCollection groups = match.Groups;
              majorVersion = int.Parse(groups["MajorVersion"].Value ??
                  throw new FormatException("VersionFile did not contain a group matching MajorVersion"));
              minorVersion = int.Parse(groups["MinorVersion"].Value ??
                  throw new FormatException("VersionFile did not contain a group matching MinorVersion"));
              patchVersion = int.Parse(groups["PatchVersion"].Value ??
                  throw new FormatException("VersionFile did not contain a group matching PatchVersion"));
          }
          foreach(Match match in matchesAssemblyFileVersion) {
              GroupCollection groups = match.Groups;
              build = int.Parse(groups["Build"].Value ??
                  throw new FormatException("VersionFile did not contain a group matching Build"));
              revision = int.Parse(groups["Revision"].Value ??
                  throw new FormatException("VersionFile did not contain a group matching Revision"));
          }
          foreach(Match match in matchesAssemblyInformationalVersion) {
              GroupCollection groups = match.Groups;
              packageVersion = groups["PackageVersion"].Value ??
                  throw new FormatException("VersionFile did not contain a group matching PackageVersion");
          }
          // Log the method exit if Debug and Trace
          if(string.Equals(aTAPBuildToolingConfiguration, "Debug", StringComparison.OrdinalIgnoreCase)
              && string.Equals(aTAPBuildToolingDebugVerbosity, "Trace", StringComparison.OrdinalIgnoreCase)) {
              log.LogMessage($"Leaving GetVersion:" +
                  $" MajorVersion = {majorVersion}" +
                  $" MinorVersion = {minorVersion}" +
                  $" PatchVersion = {patchVersion}" +
                  $" PackageVersion = {packageVersion}" +
                  $" Build = {build}" +
                  $" Revision = {revision}");
          }
          return true;
      }

      /// <summary>
    /// Create the Build and Revision portion of a System.Version based on current UTC date and time.
    /// Build Number: Days since 1.1.2000
    /// Revision: Seconds since midnight divided by two
    /// The System.Version requires that the Build and revision both be an Uint16
    /// this article goes into depth: https://stackoverflow.com/questions/3387108/details-of-assembly-version/3387167#3387167
    /// </summary>
    /// <returns>integer consisting of the 7 leftmost digits of the date string </returns>
    public static void MakeBuild(out int build, out int revision) {
        DateTime now = DateTime.Now.ToUniversalTime();
        build = (now - DateTime.Parse("Jan 1,2000")).Days;
        revision = (int)(now.TimeOfDay.TotalSeconds) / 2;
    }

      public static string MakePackageVersion(int Major, int Minor, int Patch, string LifeCycleStage, string Label, int LabelCount) {
          // removing patchStringFormat. It appears the NuSpec created by MSBuild only uses a single digit
          // ToDo: test to ensure that restore picks .10 over .9
          // removing this: {Patch.ToString(patchStringFormat)
          string str = $"{Major.ToString()}.{Minor.ToString()}.{Patch.ToString()}";
          // LifeCycleStage is Production if this is a publicly available release package 
          bool isPublicReleasePackage = (LifeCycleStage == lifeCycleStageProduction);
          // If not a PublicReleasePackage, then add a development label to the PackageVersion
          if(!isPublicReleasePackage) {
              // During testing, a "Production" package may have the Label "RC"
              if((isPublicReleasePackage && (Label == labelReleaseCandidate))
                  || (!isPublicReleasePackage
                      && ((Label != labelReleaseCandidate) || (Label != string.Empty) || (Label != null)))) {
                  if((Label != string.Empty) || (Label != null)) {
                      str += $"-{Label}-{LabelCount.ToString(labelStringFormat)}";
                  }
              } else {
                  // The combination of arguments is invalid, so throw an exception
                  throw new ArgumentException("Improper combination of arguments to MakePackageVersion");
              }
          }
          return str;
      }

    /// <summary></summary>
    /// <param name="log"></param>
    /// <param name="versionFile"></param>
    /// <param name="aTAPBuildToolingConfiguration"></param>
    /// <param name="aTAPBuildToolingDebugVerbosity"></param>
    /// <param name="build"></param>
    /// <param name="majorVersion"></param>
    /// <param name="minorVersion"></param>
    /// <param name="patchVersion"></param>
    /// <param name="packageVersion"></param>
    /// <param name="revision"></param>
    public static bool SetVersion(TaskLoggingHelper log, string versionFile, string aTAPBuildToolingConfiguration, string aTAPBuildToolingDebugVerbosity, int build, int majorVersion, int minorVersion, int patchVersion, string packageVersion, int revision) {
          // Log the method entry if Debug and Trace
          if(string.Equals(aTAPBuildToolingConfiguration, "Debug", StringComparison.OrdinalIgnoreCase)
              && string.Equals(aTAPBuildToolingDebugVerbosity, "Trace", StringComparison.OrdinalIgnoreCase)) {
              log.LogMessage($"  Starting Utilities.SetVersion, VersionFile = {versionFile}");
          }
          FileInfo versionFileInfo = new FileInfo(versionFile);

          if(!versionFileInfo.Exists) {
              log.LogWarning(versionFileInfo.FullName + " does not exist");
              return false;
          }
          // full path to VersionFile
          string path = versionFileInfo.FullName;

          // Compiled regular expression to match for the version information pieces
          Regex REAssemblyFileVersion = new Regex(strReAssemblyFileVersion, RegexOptions.IgnoreCase);
          Regex REAssemblyInformationalVersion = new Regex(strReAssemblyInformationalVersion, RegexOptions.IgnoreCase);
          Regex REAssemblyVersion = new Regex(strReAssemblyVersion, RegexOptions.IgnoreCase);

          // replacement lines with new values for each group
          string newAssemblyFileVersionLine = $"[assembly:AssemblyFileVersion(\"{majorVersion}.{minorVersion}.{build}.{revision}\")]";
          string newAssemblyVersionLine = $"[assembly:AssemblyVersion(\"{majorVersion}.{minorVersion}.{patchVersion}\")]";
          string newAssemblyInformationalVersionLine = $"[assembly:AssemblyInformationalVersion(\"{packageVersion}\")]";

          // Read in all of the lines of the VersionFile
          string[] lines = File.ReadAllLines(path);
          // prepare an output array for the modified lines for the updated VersionFile
          string[] outlines = new string[lines.Length];
          // loop all lines of the versionFile and update matching lines to the new values
          for(var i = 0; i < lines.Length; i++) {
              if(string.Equals(aTAPBuildToolingConfiguration, "Debug", StringComparison.OrdinalIgnoreCase)
                  && string.Equals(aTAPBuildToolingDebugVerbosity, "Trace", StringComparison.OrdinalIgnoreCase)) {
                  log.LogMessage($"line:Before:{lines[i]}");
              }
              if(REAssemblyVersion.IsMatch(lines[i])) {
                  outlines[i] = newAssemblyVersionLine;
                  if(string.Equals(aTAPBuildToolingConfiguration, "Debug", StringComparison.OrdinalIgnoreCase)
                      && string.Equals(aTAPBuildToolingDebugVerbosity, "Trace", StringComparison.OrdinalIgnoreCase)) {
                      log.LogMessage($"line:After:{outlines[i]}");
                  }

                  continue;
              }
              if(REAssemblyFileVersion.IsMatch(lines[i])) {
                  outlines[i] = newAssemblyFileVersionLine;
                  if(string.Equals(aTAPBuildToolingConfiguration, "Debug", StringComparison.OrdinalIgnoreCase)
                      && string.Equals(aTAPBuildToolingDebugVerbosity, "Trace", StringComparison.OrdinalIgnoreCase)) {
                      log.LogMessage($"line:After:{outlines[i]}");
                  }

                  continue;
              }
              if(REAssemblyInformationalVersion.IsMatch(lines[i])) {
                  outlines[i] = newAssemblyInformationalVersionLine;
                  if(string.Equals(aTAPBuildToolingConfiguration, "Debug", StringComparison.OrdinalIgnoreCase)
                      && string.Equals(aTAPBuildToolingDebugVerbosity, "Trace", StringComparison.OrdinalIgnoreCase)) {
                      log.LogMessage($"line:After:{outlines[i]}");
                  }

                  continue;
              }
              outlines[i] = lines[i];
              if(string.Equals(aTAPBuildToolingConfiguration, "Debug", StringComparison.OrdinalIgnoreCase)
                  && string.Equals(aTAPBuildToolingDebugVerbosity, "Trace", StringComparison.OrdinalIgnoreCase)) {
                  log.LogMessage($"line:After:{outlines[i]}");
              }
          }
          File.WriteAllLines(path, outlines, new UTF8Encoding());
          return true;
      }

    /// <summary></summary>
    /// <param name="log"></param>
    /// <param name="stringPackageVersion"></param>
    /// <param name="aTAPBuildToolingConfiguration"></param>
    /// <param name="aTAPBuildToolingDebugVerbosity"></param>
    /// <param name="isPublicReleasePackage"></param>
    /// <param name="major"></param>
    /// <param name="minor"></param>
    /// <param name="patch"></param>
    /// <param name="label"></param>
    /// <param name="labelCount"></param>
    public static bool TryParsePackageVersion(TaskLoggingHelper log, string stringPackageVersion, string aTAPBuildToolingConfiguration, string aTAPBuildToolingDebugVerbosity, out bool? isPublicReleasePackage, out int? major, out int? minor, out int? patch, out string label, out int? labelCount) {
          // Log the method entry if Debug and Trace
          if(string.Equals(aTAPBuildToolingConfiguration, "Debug", StringComparison.OrdinalIgnoreCase)
              && string.Equals(aTAPBuildToolingDebugVerbosity, "Trace", StringComparison.OrdinalIgnoreCase)) {
              log.LogMessage($"  Starting Utilities.TryParsePackageVersion, stringPackageVersion = {stringPackageVersion}");
          }
          if((stringPackageVersion == null) || (stringPackageVersion == string.Empty)) {
              isPublicReleasePackage = null;
              major = null;
              minor = null;
              patch = null;
              label = string.Empty;
              labelCount = null;
              // Log the method exit if Debug and Trace
              if(string.Equals(aTAPBuildToolingConfiguration, "Debug", StringComparison.OrdinalIgnoreCase)
                  && string.Equals(aTAPBuildToolingDebugVerbosity, "Trace", StringComparison.OrdinalIgnoreCase)) {
                  log.LogMessage($"  Leaving Utilities.TryParsePackageVersion, stringPackageVersion is null or empty");
              }
              return false;
          }
          Regex REPackageVersion = new Regex(rePackageVersion, RegexOptions.IgnoreCase);
          MatchCollection matchesPackageVersion = REPackageVersion.Matches(stringPackageVersion);
          Match match = matchesPackageVersion[0];
          GroupCollection groups = match.Groups;
          major = int.Parse(groups["Major"].Value ?? throw new ArgumentNullException(nameof(major)));
          minor = int.Parse(groups["Minor"].Value ?? throw new ArgumentNullException(nameof(minor)));
          patch = int.Parse(groups["Patch"].Value ?? throw new ArgumentNullException(nameof(patch)));
          // Log the value of isNotPublicReleasePackage if Debug and Trace
          if(string.Equals(aTAPBuildToolingConfiguration, "Debug", StringComparison.OrdinalIgnoreCase)
              && string.Equals(aTAPBuildToolingDebugVerbosity, "Trace", StringComparison.OrdinalIgnoreCase)) {
              log.LogMessage($"  in Utilities.TryParsePackageVersion, isNotPublicReleasePackage is {groups["isNotPublicReleasePackage"].Value}; and its length is {groups["isNotPublicReleasePackage"].Value.Length}");
          }
          if(groups["isNotPublicReleasePackage"].Value.Length == 0) {
              isPublicReleasePackage = true;
              label = string.Empty;
              labelCount = null;
          } else {
              isPublicReleasePackage = false;
              label = groups["Label"].Value ?? throw new ArgumentNullException(nameof(label));
              labelCount = int.Parse(groups["LabelCount"].Value ?? throw new ArgumentNullException(nameof(labelCount)));
          }
          // Log leaving TryParsePackageVersion if Debug and Trace
          if(string.Equals(aTAPBuildToolingConfiguration, "Debug", StringComparison.OrdinalIgnoreCase)
              && string.Equals(aTAPBuildToolingDebugVerbosity, "Trace", StringComparison.OrdinalIgnoreCase)) {
              log.LogMessage($"  Leaving Utilities.TryParsePackageVersion");
          }
          return true;
      }
  }

  /// <summary></summary>
  public class GetVersion : Task {
    /// <summary></summary>
    public override bool Execute() {
            // Log the method entry if Debug and Trace
            if(string.Equals(ATAPBuildToolingConfiguration, "Debug", StringComparison.OrdinalIgnoreCase)
                && string.Equals(ATAPBuildToolingDebugVerbosity, "Trace", StringComparison.OrdinalIgnoreCase)) {
                Log.LogMessage($"  Starting GetVersion, VersionFile = {VersionFile}");
            }
            // Get the current version information stored for this assembly
            bool resultGetVersion = Utilities.GetVersion(Log,
                                                         this.VersionFile,
                                                         this.ATAPBuildToolingConfiguration,
                                                         this.ATAPBuildToolingDebugVerbosity,
                                                         out int? _build,
                                                         out int? _majorVersion,
                                                         out int? _minorVersion,
                                                         out int? _patchVersion,
                                                         out string _packageVersion,
                                                         out int? _revision);
            if(!resultGetVersion) {
                Log.LogError($"  UpdateVersion: GetVersion returned false");
                return false;
            }
            if((_packageVersion == null) || (_packageVersion == string.Empty)) {
                throw new InvalidDataException($"_packageVersion from GetVersion was null or empty");
            }
      if (_majorVersion == null){throw new InvalidDataException($"_majorVersion from GetVersion was null");}
      if (_minorVersion == null) { throw new InvalidDataException($"_minorVersion from GetVersion was null"); }
      if (_patchVersion == null) { throw new InvalidDataException($"_patchVersion from GetVersion was null"); }
      if (_build == null) { throw new InvalidDataException($"_build from GetVersion was null"); }
      if (_revision == null) { throw new InvalidDataException($"_revision from GetVersion was null"); }
      // Log the results if Debug and Trace
      if (string.Equals(ATAPBuildToolingConfiguration, "Debug", StringComparison.OrdinalIgnoreCase)
                && string.Equals(ATAPBuildToolingDebugVerbosity, "Trace", StringComparison.OrdinalIgnoreCase)) {
                Log.LogMessage($"  GetVersion: _majorVersion = {_majorVersion}" +
                    $" _minorVersion = {_minorVersion}" +
                    $" _patchVersion = {_patchVersion}" +
                    $" _packageVersion = {_packageVersion}" +
                    $" _build = {_build}" +
                    $" _revision = {_revision}");
            }
      // Set the Task output properties
      MajorVersion = (int) _majorVersion;
      MinorVersion = (int) _minorVersion;
      PatchVersion = (int) _patchVersion;
      PackageVersion = _packageVersion;
      Build = (int) _build;
      Revision = (int) _revision;
            return true;
        }

    /// <summary>Allowable  values are Dev or Production</summary>
    [Required]
    public string ATAPBuildToolingConfiguration {
        get;
        set;
    }
    /// <summary></summary>
    [Required]
    public string ATAPBuildToolingDebugVerbosity {
        get;
        set;
    }
    /// <summary></summary>
    [Output]
    public long Build {
        get;
        set;
    }
    /// <summary></summary>
    [Output]
    public int MajorVersion {
        get;
        set;
    }
    /// <summary></summary>
    [Output]
    public int MinorVersion {
        get;
        set;
    }
    /// <summary></summary>
    [Output]
    public string PackageVersion {
        get;
        set;
    }
    [Output]
    public int PatchVersion {
        get;
        set;
    }
    [Output]
    public int Revision {
        get;
        set;
    }
    [Required]
    public string VersionFile {
        get;
        set;
    }
    }

    /// <summary>
  /// Updates the Build, Revision, and PackageVersion values in the VersionFile,
  /// </summary>
  /// <seealso cref="Task" />
  public class UpdateVersion : Task {
    /// <summary></summary>
    public override bool Execute() {
          // Log the method entry if Debug and Trace
          if(string.Equals(ATAPBuildToolingConfiguration, "Debug", StringComparison.OrdinalIgnoreCase)
              && string.Equals(ATAPBuildToolingDebugVerbosity, "Trace", StringComparison.OrdinalIgnoreCase)) {
              Log.LogMessage($"  Starting UpdateVersion, VersionFile = {VersionFile}");
          }

          // Get the current version information stored for this assembly
          bool resultGetVersion = Utilities.GetVersion(Log,
                                                       VersionFile,
                                                       this.ATAPBuildToolingConfiguration,
                                                       this.ATAPBuildToolingDebugVerbosity,
                                                       out int? _build,
                                                       out int? _majorVersion,
                                                       out int? _minorVersion,
                                                       out int? _patchVersion,
                                                       out string _packageVersion,
                                                       out int? _revision);
          if(!resultGetVersion) {
              Log.LogError($"  UpdateVersion: GetVersion returned false");
              return false;
          }
          // Log the results if Debug and Trace
          if(string.Equals(ATAPBuildToolingConfiguration, "Debug", StringComparison.OrdinalIgnoreCase)
              && string.Equals(ATAPBuildToolingDebugVerbosity, "Trace", StringComparison.OrdinalIgnoreCase)) {
              Log.LogMessage($"  UpdateVersion: MajorVersion = {MajorVersion}" +
                  $" MinorVersion = {MinorVersion}" +
                  $" PatchVersion = {PatchVersion}" +
                  $" PackageLabel = {PackageLabel}" +
                  $" PackageLifeCycleStage = {PackageLifeCycleStage}" +
                  $" PackageVersion = {_packageVersion}" +
                  $" Build = {_build}" +
                  $" Revision = {_revision}");
          }

          if((_packageVersion == null) || (_packageVersion == string.Empty)) {
              throw new InvalidDataException($"PackageVersion from GetVersion was null or empty");
          }
          bool isGoodPackageversion = Utilities.TryParsePackageVersion(Log,
                                                                       _packageVersion,
                                                                       this.ATAPBuildToolingConfiguration,
                                                                       this.ATAPBuildToolingDebugVerbosity,
                                                                       out bool? _oldIsPublicReleasePackage,
                                                                       out int? _majorFromPackageVersion,
                                                                       out int? _minorFromPackageVersion,
                                                                       out int? _patchFromPackageVersion,
                                                                       out string _labelFromPackageVersion,
                                                                       out int? _labelCountFromPackageVersion);
          if(!isGoodPackageversion) {
              throw new InvalidDataException($"PackageVersion from VersionFile could not be parsed: {_packageVersion}");
          }

          // Log the results if Debug and Trace
          if(string.Equals(ATAPBuildToolingConfiguration, "Debug", StringComparison.OrdinalIgnoreCase)
              && string.Equals(ATAPBuildToolingDebugVerbosity, "Trace", StringComparison.OrdinalIgnoreCase)) {
              Log.LogMessage($"  UpdateVersion after TryParsePackageVersion: _oldIsPublicReleasePackage = {_oldIsPublicReleasePackage}" +
                  $" _majorFromPackageVersion = {_majorFromPackageVersion}" +
                  $" _minorFromPackageVersion = {_minorFromPackageVersion}" +
                  $" _patchFromPackageVersion = {_patchFromPackageVersion}" +
                  $" _labelFromPackageVersion = {_labelFromPackageVersion}" +
                  $" _labelCountFromPackageVersion = {_labelCountFromPackageVersion}");
          }

          Utilities.MakeBuild(out int nowBuild, out int nowRevision);
          int? nowLabelCount;
          // if the label has changed, reset labelCount to 0
          if((_labelFromPackageVersion != PackageLabel)
              // or if the Major, Minor, or Patch has changed, reset labelCount to 0
              || ((_majorFromPackageVersion != MajorVersion) || (_minorFromPackageVersion != MinorVersion)
                  || (_patchFromPackageVersion != PatchVersion))) {
              nowLabelCount = 0;
          } else {
              // but if they are all the same, then increment the label count
              nowLabelCount = _labelCountFromPackageVersion + 1;
          }

          string _newPackageVersion = Utilities.MakePackageVersion(MajorVersion,
                                                                   MinorVersion,
                                                                   PatchVersion,
                                                                   PackageLifeCycleStage,
                                                                   PackageLabel,
                                                                   (int)nowLabelCount);

          // Log the results if Debug and Trace
          if(string.Equals(ATAPBuildToolingConfiguration, "Debug", StringComparison.OrdinalIgnoreCase)
              && string.Equals(ATAPBuildToolingDebugVerbosity, "Trace", StringComparison.OrdinalIgnoreCase)) {
              Log.LogMessage($"  UpdateVersion after MakePackageVersion: _newPackageVersion = {_newPackageVersion}");
          }
          // Set all  the new version information stored for this assembly
          bool setVersionResult = Utilities.SetVersion(Log,
                                                       VersionFile,
                                                       ATAPBuildToolingConfiguration,
                                                       ATAPBuildToolingDebugVerbosity,
                                                       nowBuild,
                                                       MajorVersion,
                                                       MinorVersion,
                                                       PatchVersion,
                                                       _newPackageVersion,
                                                       nowRevision);
          // Update output properties
          Build = nowBuild;
          PackageVersion = _newPackageVersion;
          Revision = nowRevision;
          return setVersionResult;
      }

    /// <summary></summary>
    [Required]
    public string ATAPBuildToolingConfiguration {
        get;
        set;
    }
    /// <summary>string corresponding to an allowable logging level, e.g. Trace, Debug, Error</summary>
    [Required]
    public string ATAPBuildToolingDebugVerbosity {
        get;
        set;
    }
    [Output]
    public long Build {
        get;
        set;
    }

    [Required]
    public int MajorVersion {
        get;
        set;
    }
    [Required]
    public int MinorVersion {
        get;
        set;
    }
    [Required]
    public string PackageLabel {
        get;
        set;
    }
    [Required]
    public string PackageLifeCycleStage {
        get;
        set;
    }
    [Output]
    public string PackageVersion {
        get;
        set;
    }
    [Required]
    public int PatchVersion {
        get;
        set;
    }
    /// <summary></summary>
    [Output]
    public int Revision {
        get;
        set;
    }
    /// <summary></summary>
    [Required]
    public string VersionFile {
        get;
        set;
    }
  }

  /// <summary></summary>
  public class SetVersion : Task {
        public override bool Execute() {
            bool setVersionResult = Utilities.SetVersion(Log,
                                                         VersionFile,
                                                         ATAPBuildToolingConfiguration,
                                                         ATAPBuildToolingDebugVerbosity,
                                                         Build,
                                                         MajorVersion,
                                                         MinorVersion,
                                                         PatchVersion,
                                                         PackageVersion,
                                                         Revision);
            return setVersionResult;
        }

    [Required]
    public string ATAPBuildToolingConfiguration {
        get;
        set;
    }
    [Required]
    public string ATAPBuildToolingDebugVerbosity {
        get;
        set;
    }
    [Required]
    public int Build {
        get;
        set;
    }
    [Required]
    public int MajorVersion {
        get;
        set;
    }
    [Required]
    public int MinorVersion {
        get;
        set;
    }
    [Required]
    public string PackageVersion {
        get;
        set;
    }
    [Required]
    public int PatchVersion {
        get;
        set;
    }
    [Required]
    public int Revision {
        get;
        set;
    }
    [Required]
    public string VersionFile {
        get;
        set;
    }
    }
}

