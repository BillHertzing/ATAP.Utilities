namespace ATAP.Utilities.IAC.Ansible
{
  public class AnsibleRole : IAnsibleRole
  {
    public string Name { get; set; }
    public IAnsibleMeta AnsibleMeta { get; set; }
    public IAnsibleTask AnsibleTask { get; set; }

    public AnsibleRole(string name, IAnsibleMeta ansibleMeta, IAnsibleTask ansibleTask)
    {
      Name = name;
      AnsibleMeta = ansibleMeta;
      AnsibleTask = ansibleTask;
    }
  }
}
