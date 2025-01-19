using System.Collections.Generic;

namespace ATAP.Utilities.IAC.Ansible {
  public interface IAnsibleRole {
    AnsibleRoleNamesEnum Name { get; }
    IAnsibleMeta AnsibleMeta { get; }
    IAnsibleTask AnsibleTask { get; }
  }
}
