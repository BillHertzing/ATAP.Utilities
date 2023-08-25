

using System;
using System.IO;
using System.Collections.Generic;
using YamlDotNet.Core;
using YamlDotNet.Core.Events;
using YamlDotNet.Serialization;
using System.Reflection;
namespace ATAP.Utilities.Ansible
{
  public enum AnsiblePlayBlockKind
  {
    AnsiblePlayBlockChocolateyPackages,
    AnsiblePlayBlockRegistrySettings
  }
  // AnsiblePlayBlockCommon interface capturing shared components
  public interface IAnsiblePlayBlockCommon
  {
    string Name { get; set; }
  }
  // Interface for AnsiblePlayBlockChocolateyPackages, derived from IAnsiblePlayBlockCommon
  public interface IAnsiblePlayBlockChocolateyPackages : IAnsiblePlayBlockCommon
  {
    string Version { get; set; }
    bool Prerelease { get; set; }
  }
  // Interface for AnsiblePlayBlockRegistrySettings, derived from IAnsiblePlayBlockCommon
  public interface IAnsiblePlayBlockRegistrySettings : IAnsiblePlayBlockCommon
  {
    string Path { get; set; }
    string Type { get; set; }
    string Value { get; set; }
  }
  public class AnsiblePlayBlockChocolateyPackages : IAnsiblePlayBlockChocolateyPackages
  {
    public string Name { get; set; }
    public string Version { get; set; }
    public bool Prerelease { get; set; }
    public AnsiblePlayBlockChocolateyPackages(string name, string version, bool prerelease)
    {
      Name = name;
      Version = version;
      Prerelease = prerelease;
    }
  }
  public class AnsiblePlayBlockRegistrySettings : IAnsiblePlayBlockRegistrySettings
  {
    public string Name { get; set; }
    public string Path { get; set; }
    public string Type { get; set; }
    public string Value { get; set; }
    public AnsiblePlayBlockRegistrySettings(string name, string path, string type, string value)
    {
      Name = name;
      Path = path;
      Type = type;
      Value = value;
    }
  }
  public interface IAnsiblePlay
  {
    string Name { get; set; }
    AnsiblePlayBlockKind Kind { get; }

    List<IAnsiblePlayBlockCommon> Items { get; set; }
  }
  public class AnsiblePlay : IAnsiblePlay
  {
    public string Name { get; set; }
    public AnsiblePlayBlockKind Kind { get; private set; }
    public List<IAnsiblePlayBlockCommon> Items { get; set; }
    public AnsiblePlay(string name, AnsiblePlayBlockKind kind, List<IAnsiblePlayBlockCommon> items)
    {
      Name = name;
      Items = items;
      Kind = kind;
    }
  }
  public class AnsibleTask
  {
    public string Name { get; set; }
    public List<IAnsiblePlay> Items { get; set; }

    public AnsibleTask(string name, List<IAnsiblePlay> items)
    {
      Name = name;
      Items = items;
    }
  }

}

// public class ListOfAnsiblePlayBlockAny
// {
//   public AnsiblePlayBlockKind AnsiblePlayBlockKind { get; set; }
//   public List<IAnsiblePlayBlockCommon> Items { get; set; } // Generic list field of IAnsiblePlayBlockCommon  interfaces (can be either concrete type)
//   public ListOfAnsiblePlayBlockAny(AnsiblePlayBlockKind ansiblePlayBlockKind, List<IAnsiblePlayBlockCommon > items)
//   {
//     AnsiblePlayBlockKind = ansiblePlayBlockKind;
//     Items = items;
//   }
//   public string ConvertToYaml()
//   {
//     var serializer = new SerializerBuilder().Build();
//     return serializer.Serialize(this);
//   }
//   public static ListOfAnsiblePlayBlockAny ConvertFromYaml(string yaml)
//   {
//     var deserializer = new DeserializerBuilder()
//     .WithTypeConverter(new InterfaceConverter<IAnsiblePlayBlockChocolateyPackages, AnsiblePlayBlockChocolateyPackages>())
//     .WithTypeConverter(new InterfaceConverter<IAnsiblePlayBlockRegistrySettings, AnsiblePlayBlockRegistrySettings>())

//     .Build();
//     return deserializer.Deserialize<ListOfAnsiblePlayBlockAny>(yaml);
//   }
// }

// public class InterfaceConverter<TInterface, TConcrete> : IYamlTypeConverter
//   where TConcrete : TInterface
// {
//   public bool Accepts(Type type)
//   {
//     return type == typeof(TInterface);
//   }

//   public object ReadYaml(IParser parser, Type type)
//   {
//     // Delegate to the existing deserialization method for TConcrete
//     var yaml = parser.Consume<Scalar>().Value;
//     var method = typeof(TConcrete).GetMethod("ConvertFromYaml", BindingFlags.Static | BindingFlags.Public);
//     return method.Invoke(null, new object[] { yaml });
//   }

//   public void WriteYaml(IEmitter emitter, object value, Type type)
//   {
//     // Delegate to the existing serialization method for TConcrete
//     var method = typeof(TConcrete).GetMethod("ConvertToYaml", BindingFlags.Instance | BindingFlags.Public);
//     var yaml = method.Invoke(value, null) as string;
//     emitter.Emit(new Scalar(null, yaml));
//   }
// }
