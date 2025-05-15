namespace ATAP.Utilities.IAC.Ansible {
  public record AnsibleRole : IAnsibleRole {
    public AnsibleRoleNamesEnum Name { get; }
    public IAnsibleMeta AnsibleMeta { get; }
    public IAnsibleTask AnsibleTask { get; }

    public ITaskDefinitions TaskDefinitions { get; }

    public AnsibleRole(AnsibleRoleNamesEnum name, IAnsibleMeta ansibleMeta, IAnsibleTask ansibleTask, ITaskDefinitions taskDefinitions) {
      Name = name;
      AnsibleMeta = ansibleMeta;
      AnsibleTask = ansibleTask;
      TaskDefinitions = taskDefinitions;
    }
  }
}
