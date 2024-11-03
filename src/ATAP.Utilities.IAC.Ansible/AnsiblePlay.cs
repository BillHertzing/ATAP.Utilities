namespace ATAP.Utilities.IAC.Ansible
{
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
}
