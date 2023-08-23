public class InterfaceConverter<TInterface, TConcrete> : IYamlTypeConverter
    where TConcrete : TInterface
{
    public bool Accepts(Type type)
    {
        return type == typeof(TInterface);
    }

    public object ReadYaml(YamlDotNet.Serialization.IParser parser, Type type)
    {
        // Implementation for reading YAML and converting to TConcrete
    }

    public void WriteYaml(YamlDotNet.Serialization.IEmitter emitter, object value, Type type)
    {
        // Implementation for writing TConcrete to YAML
    }
}
