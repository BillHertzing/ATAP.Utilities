public interface IAnsibleScriptBlock
{
    AnsibleScriptBlockKinds Kind { get; set; } // ToDo: Make Kind immutable
    List<IScriptBlockArguments> Items { get; set; } // ToDo: Make Items  immutable

    string ConvertToYaml();
}
