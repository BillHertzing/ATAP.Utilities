public interface IRegistrySettingsArgument : IScriptBlockArguments
{
  string Purpose { get; set; }
  string Data { get; set; }
  string Type { get; set; }
  string Path { get; set; }
}
