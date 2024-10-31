namespace ATAP.Utilities.IAC.Ansible.Interfaces
{
    public interface IAnsibleRole
    {
        string Name { get; set; }
        IAnsibleMeta AnsibleMeta { get; set; }
        IAnsibleTask AnsibleTask { get; set; }

    }
}
