public class AnsibleScriptBlock : IAnsibleScriptBlock
{
  public AnsibleScriptBlockKinds Kind { get; set; } // ToDo: Make Kind immutable
  public List<IScriptBlockArguments> Items { get; set; } // ToDo: Make Items  immutable

  public AnsibleScriptBlock(AnsibleScriptBlockKinds kind, List<IScriptBlockArguments> items)
  {
    Kind = kind;
    Items = items;
  }

  static AnsibleScriptBlock Create(AnsibleScriptBlockKinds kind, List<IScriptBlockArguments> items)
  {
    return new AnsibleScriptBlock(kind, items);
  }

  public string ConvertToYaml()
  {
    var serializer = new YamlDotNet.Serialization.SerializerBuilder().Build();
    return serializer.Serialize(this);
  }

  public static AnsibleScriptBlock ConvertFromYaml(string yamlContent)
  {
    Dictionary<string, List<IScriptBlockArguments>> yamlObject;
    var deserializer = new YamlDotNet.Serialization.DeserializerBuilder()
      .WithTypeConverter(new InterfaceConverter<IScriptBlockArguments, ChocolateyPackageArguments>())
      .WithTypeConverter(new InterfaceConverter<IScriptBlockArguments, RegistrySettingsArgument>())
      .Build();
    var aSB = deserializer.Deserialize<AnsibleScriptBlock>(yamlContent);
    // AnsibleScriptBlockKinds kind;
    // string kindAsString = "ChocolateyPackages";
    // if (!Enum.TryParse<AnsibleScriptBlockKinds>(kindAsString, out AnsibleScriptBlockKinds kind))
    // {
    //   // ToDo: Logging
    //   // ToDo: error messages in the string constants
    //   throw new ArgumentException("Invalid identifier");
    // }
    // //  declare an list that will hold the arguments
    // lclScriptBlockArguments = new List<IScriptBlockArguments>();
    // // switch on kind to parse the arguments
    // switch (kind)
    // {
    //   case AnsibleScriptBlockKinds.ChocolateyPackages:
    //     IScriptBlockArguments scriptBlockArguments = yamlObject["ScriptBlockArguments"];
    //     break;
    //   case AnsibleScriptBlockKinds.RegistrySettings:
    //     IScriptBlockArguments scriptBlockArguments = yamlObject["ScriptBlockArguments"];
    //     break;
    // }
    return Create(aSB.Kind, aSB.Items);
  }

}
