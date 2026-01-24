# Ansible Guidelines
- Organize playbooks/roles under `/ops/ansible`; inventory and group vars must not contain secrets—use Ansible Vault or external secrets provider.
- Parameterize environment via variables; validate before run.
- Generate documentation snippets in `/docs/ops` where applicable.
