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
