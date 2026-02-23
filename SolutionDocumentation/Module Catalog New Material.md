<img src="https://r2cdn.perplexity.ai/pplx-full-logo-primary-dark%402x.png" style="height:64px;margin-right:32px"/>

# compare proget's make tool and jenkins.

ProGet’s “Make” is not the same kind of product as Jenkins: Jenkins is a CI automation server for running pipelines/jobs, while ProGet is primarily a package registry/repository (NuGet/npm/Maven/Docker/etc.) focused on storing, securing, scanning, and promoting packages you build elsewhere.[^1_1][^1_2]

## What each tool is for

- **Jenkins**: An open-source automation server commonly used to build/test/deploy via scripted pipelines (e.g., Jenkins Pipeline steps in a Jenkinsfile).[^1_1]
- **ProGet**: A package manager/repository that hosts and curates packages/containers, adds controls like approval workflows, vulnerability/license scanning, and package promotion across stages.[^1_3][^1_2]

## Core capability differences

- **Build execution**: Jenkins runs the build/test steps itself (agents, stages, steps). ProGet generally doesn’t replace your CI runner; instead it integrates with CI and can ingest build/SCA data (e.g., SBOM publishing and build scanning via `pgutil`).[^1_4][^1_5][^1_1]
- **Artifact/package management**: Jenkins can store “artifacts,” but ProGet is designed as the system-of-record for versioned packages/containers and related metadata/policies.[^1_6][^1_2]
- **Security/compliance**: ProGet emphasizes SCA/vulnerability scanning and policy/approval workflows around what packages are allowed and how they move to production.[^1_2][^1_3]

## How they commonly work together

A common pattern is: **Jenkins builds** → **publishes packages to ProGet** → downstream deployment tools/environments pull approved, versioned packages from ProGet. Jenkins can integrate with ProGet (including Universal Packages) using a Jenkins plugin and/or API keys.[^1_6][^1_2]

## When to pick which (rule of thumb)

- Pick **Jenkins** when you need a flexible engine to orchestrate builds/tests across repos/branches with a huge plugin ecosystem.[^1_1]
- Pick **ProGet** when you need a hardened internal registry with caching, promotion, and security/compliance controls around dependencies and release artifacts.[^1_3][^1_2]

If you meant a specific “ProGet Make” feature (or an Inedo product name/version), tell me what page or UI you’re looking at, and I’ll map it precisely to the closest Jenkins equivalent.
<span style="display:none">[^1_10][^1_11][^1_12][^1_13][^1_14][^1_15][^1_16][^1_17][^1_18][^1_19][^1_20][^1_21][^1_22][^1_23][^1_7][^1_8][^1_9]</span>

<div align="center">⁂</div>

[^1_1]: https://www.jenkins.io/doc/pipeline/steps/

[^1_2]: https://inedo.com/proget

[^1_3]: https://inedo.com/proget/features

[^1_4]: https://docs.inedo.com/docs/proget-sca-ci

[^1_5]: https://docs.inedo.com/docs/proget-sca-api

[^1_6]: https://blog.inedo.com/jenkins/universal-packages-in-proget

[^1_7]: https://www.trustradius.com/compare-products/jenkins-vs-proget

[^1_8]: https://www.reddit.com/r/selfhosted/comments/nudv3g/from_zero_to_a_docker_app_using_jenkins_proget/

[^1_9]: https://en.wikipedia.org/wiki/ProGet

[^1_10]: https://docs.inedo.com/docs/proget-sca-projects-releases

[^1_11]: https://stackoverflow.com/questions/60861091/differences-between-jenkins-projects

[^1_12]: https://docs.inedo.com/docs/buildmaster-build-scripts

[^1_13]: https://jazz.net/forum/questions/213428/rtc-build-engine-vs-jenkins-build-via-rtc-source-control

[^1_14]: https://blog.packagecloud.io/repository-showdown-artifactory-vs-nexus-vs-proget/

[^1_15]: https://forums.inedo.com/topic/1502/proget-jenkins-plugin-not-working-on-slaves

[^1_16]: https://inedo.com/buildmaster/features

[^1_17]: https://docs.inedo.com/docs/otter-otterscript-and-operations

[^1_18]: https://blog.inedo.com/jenkins/jenkins-vs-buildmaster

[^1_19]: https://docs.inedo.com/docs/buildmaster-overview

[^1_20]: https://docs.inedo.com/docs/buildmaster-otterscript-overview

[^1_21]: https://docs.inedo.com/docs/buildmaster-integrations-jenkins

[^1_22]: https://inedo.com/buildmaster

[^1_23]: https://docs.inedo.com/docs/buildmaster-scripts
