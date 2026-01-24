# Jenkins Guidelines
- Use declarative pipelines; read configuration from environment and HostSettings files where the agent provides them.
- Pull secrets from the Jenkins credentials store or the shared secrets vault; never echo secrets.
- Parallelize tests (Pester/xUnit) and publish artifacts/diagrams to `_generated`.
