# Getting Started

## Overview

This guide describes the 5-tier lifecycle flow for the ATAP.Utilities.BuildTooling.PowerShell module.

## 5-Tier Flow

1. Build and validate in the Experimental tier.
2. Promote to Development after unit-level validation.
3. Promote to Integration after cross-module integration validation.
4. Promote to QA after quality gates pass.
5. Promote to Stable after release validation and approval.

## Standard Local Workflow

```powershell

```

## Promotion Guidance

- Use BuildMaster stage pipelines for inter-tier progression.
- Keep artifact movement aligned with permanent powershellget-* feed names.
- Load package-repository host settings before feed operations. Build tooling
  resolves feed names, endpoints, and API-key environment variable names from
  `$global:Settings[$global:configRootKeys['ProGetFeedCollectionConfigRootKey']]`.
- Apply the Explainer 0111 dependency rule during restore and validation:
  a module may consume supplier packages only from its own tier or a more stable
  tier.
- Record rollout issues in sprint retrospective notes before sprint-end teardown.

