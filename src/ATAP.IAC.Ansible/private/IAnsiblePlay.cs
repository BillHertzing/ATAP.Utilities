  public interface IAnsiblePlay
  {
    string Name { get; set; }
    AnsiblePlayBlockKind Kind { get; }

    List<IAnsiblePlayBlockCommon> Items { get; set; }
  }
