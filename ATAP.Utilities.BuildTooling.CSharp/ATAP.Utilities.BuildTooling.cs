using System;
using System.IO;
using System.Text;
using System.Text.RegularExpressions;
using Microsoft.Build.Framework;
using Microsoft.Build.Utilities;

namespace ATAP.Utilities.BuildTooling {
    public class SayHello : Task {
        public override bool Execute() {
            Log.LogMessage(MessageImportance.High, "Aloha");
            return true;
        }
    }

    public class SetVersion : Task {
        public override bool Execute() {
            // Regular Expression Regex strings for patterns to match for the version information pieces
            string reAssemblyVersion = @"AssemblyVersion\("".*""\)";
            string reAssemblyFileVersion = @"AssemblyFileVersion\("".*""\)";
            string reAssemblyInformationalVersion = @"AssemblyInformationalVersion\("".*""\)";
            // Compiled regular expression to match for the version information pieces
            Regex REAssemblyVersion = new Regex(reAssemblyVersion, RegexOptions.IgnoreCase);
            Regex REAssemblyFileVersion = new Regex(reAssemblyFileVersion, RegexOptions.IgnoreCase);
            Regex REAssemblyInformationalVersion = new Regex(reAssemblyInformationalVersion, RegexOptions.IgnoreCase);

            string build = BuildString.Make();

            FileInfo versionFileInfo = new FileInfo(VersionFile);

            if(!versionFileInfo.Exists) {
                Log.LogWarning(versionFileInfo.FullName + " does not exist");
                return false;
            }
            string path = versionFileInfo.FullName;
            string[] lines = File.ReadAllLines(path);
            string[] outlines = new string[lines.Length];
            string line;
            for(var i = 0; i < lines.Length; i++) {
                line = lines[i];
                REAssemblyVersion.Replace(line, @"AssemblyVersion(""{Major}.{Minor}.{Build}.{Revision}"")");
                REAssemblyFileVersion.Replace(line, @"AssemblyFileVersion(""{Major}.{Minor}.{Build}.{Revision}"")");
                REAssemblyInformationalVersion.Replace(line,
                                                       @"AssemblyInformationalVersion(""{Major}.{Minor}.{PackageVersion}"")");
                outlines[i] = line;
            }
            File.WriteAllLines(path, outlines, new UTF8Encoding());
            return true;
        }

    [Required]
    public int Major {
        get;
        set;
    }
    [Required]
    public int Minor {
        get;
        set;
    }
    [Required]
    public string PackageVersion {
        get;
        set;
    }
    [Required]
    public int Patch {
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

    public static class BuildString {
        public static string Make() {
            TimeSpan elapsed = DateTime.Now.Subtract(DateTime.Parse("1-1-2000"));
            double daysAgo = elapsed.TotalDays;
            return daysAgo.ToString();
        }
    }

    public class GetVersion : Task {
        public override bool Execute() {
            // Regular Expression Regex strings for patterns to match for the version information pieces
            string reAssemblyVersion = @"AssemblyVersion\(""\s*(?<Major>\d+)\.(?<Minor>\d+)\.(?<Patch>\d+).*""\s*\)";
            string reAssemblyFileVersion = @"AssemblyFileVersion\(""\s*(?<Major>\d+)\.(?<Minor>\d+)\.(?<Build>.+)\.(?<Revision>\d+)\s*""\s*\)";
            string reAssemblyInformationalVersion = @"AssemblyInformationalVersion\(""\s*(?<Major>\d+)\.(?<Minor>\d+)\.(?<PackageVersion>.+)\s*""\)";
            // Compiled regular expression to match for the version information pieces
            Regex REAssemblyVersion = new Regex(reAssemblyVersion, RegexOptions.IgnoreCase);
            Regex REAssemblyFileVersion = new Regex(reAssemblyFileVersion, RegexOptions.IgnoreCase);
            Regex REAssemblyInformationalVersion = new Regex(reAssemblyInformationalVersion, RegexOptions.IgnoreCase);

            FileInfo versionFileInfo = new FileInfo(VersionFile);

            if(!versionFileInfo.Exists) {
                Log.LogWarning(versionFileInfo.FullName + " does not exist");
                return false;
            }
            string path = versionFileInfo.FullName;
            string text = File.ReadAllText(path);
            MatchCollection matchesAssemblyVersion = REAssemblyVersion.Matches(text);
            MatchCollection matchesAssemblyFileVersion = REAssemblyFileVersion.Matches(text);
            MatchCollection matchesAssemblyInformationalVersion = REAssemblyInformationalVersion.Matches(text);
            foreach(Match match in matchesAssemblyVersion) {
                GroupCollection groups = match.Groups;
                Major = int.Parse(groups["Major"].Value ?? throw new ArgumentNullException(nameof(Major)));
                Minor = int.Parse(groups["Minor"].Value ?? throw new ArgumentNullException(nameof(Minor)));
                Patch = int.Parse(groups["Patch"].Value ?? throw new ArgumentNullException(nameof(Patch)));
            }
            foreach(Match match in matchesAssemblyFileVersion) {
                GroupCollection groups = match.Groups;
                Build = groups["Build"].Value ?? throw new ArgumentNullException(nameof(Build));
                Revision = int.Parse(groups["Revision"].Value ?? throw new ArgumentNullException(nameof(Revision)));
            }
            foreach(Match match in matchesAssemblyInformationalVersion) {
                GroupCollection groups = match.Groups;
                PackageVersion = $"{Major}.{Minor}.{groups["PackageVersion"].Value ?? throw new ArgumentNullException(nameof(PackageVersion))}";
            }
            return true;
        }

    [Output]
    public string Build {
        get;
        set;
    }
    [Output]
    public int Major {
        get;
        set;
    }
    [Output]
    public int Minor {
        get;
        set;
    }
    [Output]
    public string PackageVersion {
        get;
        set;
    }
    [Output]
    public int Patch {
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
}
