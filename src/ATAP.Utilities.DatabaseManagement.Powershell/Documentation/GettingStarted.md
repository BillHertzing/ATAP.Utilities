# Getting Started

## Overview

This guide describes the 5-tier lifecycle flow for the ATAP.Utilities.DatabaseManagement.Powershell module.

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
- Record rollout issues in sprint retrospective notes before sprint-end teardown.

