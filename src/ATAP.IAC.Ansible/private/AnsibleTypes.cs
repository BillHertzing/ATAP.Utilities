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
    }

    public interface IRegistrySettingsArgument : IScriptBlockArguments
    {
        string Purpose { get; set; }
        string Data { get; set; }
        string Type { get; set; }
        string Path { get; set; }
    }

    public interface IChocolateyPackageArguments : IScriptBlockArguments
    {
        string Name { get; set; }
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

    public IScriptBlockArguments ConvertFromYaml(string yamlContent)
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

  public class ChocolateyPackageArguments : IChocolateyPackageArguments
  {
    public string Name { get; set; }

    public ChocolateyPackageArguments() { }

    public ChocolateyPackageArguments(string name)
    {
      Name = name;
    }


    public IChocolateyPackageArguments ConvertFromYaml(string yamlContent)
    {
      var deserializer = new YamlDotNet.Serialization.DeserializerBuilder().Build();
      return deserializer.Deserialize<ChocolateyPackageArguments>(yamlContent);
    }

    public string ConvertToYaml()
    {
      var serializer = new YamlDotNet.Serialization.SerializerBuilder().Build();
      return serializer.Serialize(this);
    }

        publicI ChocolateyPackageArguments ConvertFromYaml(string yamlContent)
    {
      var deserializer = new DeserializerBuilder().Build();
      return deserializer.Deserialize<ChocolateyPackageArgument>(yamlContent);
    }



  }

  public interface IScriptBlockArguments
  {
    ATAP.Utilities.Ansible.IScriptBlockArguments ConvertFromYaml(string yamlContent);
    string ConvertToYaml();
  }

  public class AnsibleScriptBlock
  {
    public ATAP.Utilities.Ansible.AnsibleScriptBlockKinds Kind { get; } // Make Kind immutable
    public IReadOnlyList<ATAP.Utilities.Ansible.IScriptBlockArguments> ScriptBlockArguments { get; } // Make ScriptBlockArguments immutable

    public AnsibleScriptBlock(ATAP.Utilities.Ansible.AnsibleScriptBlockKinds kind, IReadOnlyList<ATAP.Utilities.Ansible.IScriptBlockArguments> scriptBlockArguments)
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
    public List<ATAP.Utilities.Ansible.AnsibleScriptBlock> AnsibleScriptBlocks { get; set; }

    public Play()
    {
      AnsibleScriptBlocks = new List<ATAP.Utilities.Ansible.AnsibleScriptBlock>();
    }

    public static ATAP.Utilities.Ansible.Play ConvertFromYaml(string yamlContent)
    {
      var deserializer = new YamlDotNet.Serialization.DeserializerBuilder().Build();
      return deserializer.Deserialize<ATAP.Utilities.Ansible.Play>(yamlContent);
    }

    public string ConvertToYaml()
    {
      var serializer = new YamlDotNet.Serialization.SerializerBuilder().Build();
      return serializer.Serialize(this);
    }
  }

  public interface IAnsibleTask
  {
    List<ATAP.Utilities.Ansible.Play> Plays { get; }
  }

  public interface IAnsibleMeta
  {
    string DependentRoleNames { get; set; }
  }

  public class AnsibleTask : ATAP.Utilities.Ansible.IAnsibleTask
  {
    public List<ATAP.Utilities.Ansible.Play> Plays { get; }

    public AnsibleTask(IEnumerable<ATAP.Utilities.Ansible.Play> plays)
    {
      Plays = new List<ATAP.Utilities.Ansible.Play>(plays);
    }

    public AnsibleTask()
    {
      Plays = new List<ATAP.Utilities.Ansible.Play>();
    }

    public static ATAP.Utilities.Ansible.AnsibleTask ConvertFromYaml(string yamlContent)
    {
      var deserializer = new YamlDotNet.Serialization.DeserializerBuilder().Build();
      return deserializer.Deserialize<ATAP.Utilities.Ansible.AnsibleTask>(yamlContent);
    }

    public string ConvertToYaml()
    {
      var serializer = new YamlDotNet.Serialization.SerializerBuilder().Build();
      return serializer.Serialize(this);
    }
  }

  public class AnsibleMeta : ATAP.Utilities.Ansible.IAnsibleMeta
  {
    public string DependentRoleNames { get; set; }

    public AnsibleMeta() { }
  }

  public class AnsibleRole
  {
    public string Name { get; set; }
    public ATAP.Utilities.Ansible.IAnsibleMeta AnsibleMeta { get; set; }
    public ATAP.Utilities.Ansible.IAnsibleTask AnsibleTask { get; set; }

    public AnsibleRole()
    {
      AnsibleMeta = new ATAP.Utilities.Ansible.AnsibleMeta();
      AnsibleTask = new ATAP.Utilities.Ansible.AnsibleTask();
    }

    public AnsibleRole(string name, ATAP.Utilities.Ansible.IAnsibleMeta ansibleMeta, ATAP.Utilities.Ansible.IAnsibleTask ansibleTask)
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
