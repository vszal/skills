# Agent Skills 

[![Install via skills.sh](https://img.shields.io/badge/skills.sh-install-green)](https://skills.sh/vszal/skills)

This repository contains development [Agent Skills](https://agentskills.io/home) for GKE node autoscaling features like ComputeClasses and Cluster Autoscaler. This is not an official Google repo. 
Use the [Google skills repo](https://github.com/google/skills) for more stable verions.

## Installation

```bash
npx skills add vszal/skills
```

From the `npx install` command, you can select the specific skills from this
repo to install.

## Available Skills

| Skill | Description | Maturity |
| :--- | :--- | :--- |
| [**GKE ComputeClasses**](./gke-compute-classes) | Priority-based node provisioning and fallback management. | [Google skills repo](https://github.com/google/skills)  |
| [**GKE Cluster Autoscaler**](./gke-cluster-autoscaler) | Optimization, consolidation tuning, and debugging pending pods. | [Google skills repo](https://github.com/google/skills)  |
