using System.Collections.Generic;
namespace ATAP.Utilities.IAC.Ansible {
  public class AnsiblePlay : IAnsiblePlay {
    public string Name { get; set; }
    public AnsiblePlayBlockKindEnum Kind { get; private set; }
    public List<IAnsiblePlayBlockCommon> Items { get; set; }
    public AnsiblePlay(string name, AnsiblePlayBlockKindEnum kind, List<IAnsiblePlayBlockCommon> items) {
      Name = name;
      Items = items;
      Kind = kind;
    }
  }
}
