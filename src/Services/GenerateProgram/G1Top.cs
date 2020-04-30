namespace GenerateProgram {
  public class G1Top {
    public string [] NamespaceGroups { get; set; }
    public GUsing[] GUsings { get; set; }
    //public GInterface[] GInterfaces
    public GClass[] GClasses { get; set; }
    public GClass Program { get; set; }
    //public GMethod Main { get; set; }
    public string GInheritence { get; set; }
    public string[] GImplements { get; set; }
    public GPropertyGroup[] GPropertyGroups { get; set; }
    public GConstructor[] GConstructors { get; set; }

  }
}
