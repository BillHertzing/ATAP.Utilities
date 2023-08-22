

#$AnsibleTypeCode = Get-Content AnsibleTypes.cs -raw
$AnsibleTypeCode = @"
using System;
using System.IO;
using System.Collections.Generic;
using YamlDotNet.Serialization;

namespace ATAP.Utilities.Ansible
{
  public enum AnsibleScriptBlockKinds
  {
    ChocolateyPackages,
    RegistrySettings
  }

 public interface IScriptBlockArguments
    {
        string ConvertToYaml();
       # IScriptBlockArguments ConvertFromYaml(string yamlContent);
    }

    public interface IRegistrySettingsArgument : IScriptBlockArguments
    {
        string Purpose { get; set; }
        string Data { get; set; }
        string Type { get; set; }
        string Path { get; set; }
    }

  public class RegistrySettingsArgument : IRegistrySettingsArgument
  {
    public string Purpose { get; set; }
    public string Data { get; set; }
    public string Type { get; set; }
    public string Path { get; set; }

    public RegistrySettingsArgument() { }

    public RegistrySettingsArgument(string purpose, string data, string type, string path)
    {
      Purpose = purpose;
      Data = data;
      Type = type;
      Path = path;
    }

    public static RegistrySettingsArgument  ConvertFromYaml(string yamlContent)
    {
      var deserializer = new DeserializerBuilder().Build();
      return deserializer.Deserialize<RegistrySettingsArgument>(yamlContent);
    }

    public string ConvertToYaml()

    {
      var serializer = new SerializerBuilder().Build();
      return serializer.Serialize(this);
    }

    public static RegistrySettingsArgument Create(string purpose, string data, string type, string path)
    {
      return new RegistrySettingsArgument
      {
        Purpose = purpose,
        Data = data,
        Type = type,
        Path = path
      };
    }
  }

  public interface IChocolateyPackageArguments : IScriptBlockArguments
  {
      string Name { get; set; }
  }

  public class ChocolateyPackageArguments : IChocolateyPackageArguments
  {
    public string Name { get; set; }

    public ChocolateyPackageArguments() { }

    public ChocolateyPackageArguments(string name)
    {
      Name = name;
    }

    public static ChocolateyPackageArguments  ConvertFromYaml(string yamlContent)
    {
      var deserializer = new YamlDotNet.Serialization.DeserializerBuilder().Build();
      return deserializer.Deserialize<ChocolateyPackageArguments>(yamlContent);
    }

    public string ConvertToYaml()
    {
      var serializer = new YamlDotNet.Serialization.SerializerBuilder().Build();
      return serializer.Serialize(this);
    }

  }

  public class AnsibleScriptBlock
  {
    public AnsibleScriptBlockKinds Kind { get; } // Make Kind immutable
    public IReadOnlyList<IScriptBlockArguments> ScriptBlockArguments { get; } // Make ScriptBlockArguments immutable

    public AnsibleScriptBlock(AnsibleScriptBlockKinds kind, IReadOnlyList<IScriptBlockArguments> scriptBlockArguments)
    {
      Kind = kind;
      ScriptBlockArguments = scriptBlockArguments;
    }

    public string ConvertToYaml()
    {
      var serializer = new YamlDotNet.Serialization.SerializerBuilder().Build();
      return serializer.Serialize(this);
    }
  }

  public class Play
  {
    public string Name { get; set; }
    public List<AnsibleScriptBlock> AnsibleScriptBlocks { get; set; }

    public Play()
    {
      AnsibleScriptBlocks = new List<AnsibleScriptBlock>();
    }

    public static Play ConvertFromYaml(string yamlContent)
    {
      var deserializer = new YamlDotNet.Serialization.DeserializerBuilder().Build();
      return deserializer.Deserialize<Play>(yamlContent);
    }

    public string ConvertToYaml()
    {
      var serializer = new YamlDotNet.Serialization.SerializerBuilder().Build();
      return serializer.Serialize(this);
    }
  }

  public interface IAnsibleTask
  {
    List<Play> Plays { get; }
  }

  public interface IAnsibleMeta
  {
    string DependentRoleNames { get; set; }
  }

  public class AnsibleTask : IAnsibleTask
  {
    public List<Play> Plays { get; }

    public AnsibleTask(IEnumerable<Play> plays)
    {
      Plays = new List<Play>(plays);
    }

    public AnsibleTask()
    {
      Plays = new List<Play>();
    }

    public static AnsibleTask ConvertFromYaml(string yamlContent)
    {
      var deserializer = new YamlDotNet.Serialization.DeserializerBuilder().Build();
      return deserializer.Deserialize<AnsibleTask>(yamlContent);
    }

    public string ConvertToYaml()
    {
      var serializer = new YamlDotNet.Serialization.SerializerBuilder().Build();
      return serializer.Serialize(this);
    }
  }

  public class AnsibleMeta : IAnsibleMeta
  {
    public string DependentRoleNames { get; set; }

    public AnsibleMeta() { }
  }

  public class AnsibleRole
  {
    public string Name { get; set; }
    public IAnsibleMeta AnsibleMeta { get; set; }
    public IAnsibleTask AnsibleTask { get; set; }

    public AnsibleRole()
    {
      AnsibleMeta = new AnsibleMeta();
      AnsibleTask = new AnsibleTask();
    }

    public AnsibleRole(string name, IAnsibleMeta ansibleMeta, IAnsibleTask ansibleTask)
    {
      Name = name;
      AnsibleMeta = ansibleMeta;
      AnsibleTask = ansibleTask;
    }
    public static AnsibleRole ConvertFromYaml(string yamlContent)
    {
      var deserializer = new DeserializerBuilder().Build();
      return deserializer.Deserialize<AnsibleRole>(yamlContent);
    }

    public string ConvertToYaml()
    {
      var serializer = new SerializerBuilder().Build();
      return serializer.Serialize(this);
    }
  }
}

"@
$outputFilePath = join-path ".." "AnsibleTypes.dll"
if (Test-Path $outputFilePath) { Remove-Item $outputFilePath -Force}

# add references to external assemblies. Ensure the assemblies referenced are compatable with the current default DotNet framework
# reference the YamlDotNet.dll assembly found in the current directory
$yamlDotNetAssemblyPath = join-path ".." "YamlDotNet.dll"

$referencedAssemblies = @(
    $yamlDotNetAssemblyPath
    'System.Collections.dll'
)

# Now you can use the YamlDotNet classes and functions in your PowerShell script
# Compile and generate the DLL using Add-Type cmdlet
Add-Type -TypeDefinition $AnsibleTypeCode -ReferencedAssemblies $referencedAssemblies -OutputAssembly $outputFilePath

