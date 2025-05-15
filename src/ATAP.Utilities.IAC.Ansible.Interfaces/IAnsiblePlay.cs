using System.Collections.Generic;

namespace ATAP.Utilities.IAC.Ansible {
  public interface IAnsiblePlay {
    string Name { get; set; }
    AnsiblePlayBlockKindEnum Kind { get; }

    List<IAnsiblePlayBlockCommon> Items { get; set; }
  }
}
