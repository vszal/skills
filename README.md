# Agent Skills 

[![Install via skills.sh](https://img.shields.io/badge/skills.sh-install-green)](https://skills.sh/vszal/skills)

This repository contains experimental [Agent Skills](https://agentskills.io/home) for GKE features like ComputeClasses. This is not an official Google repo. 
Use the [Google skills repo](https://github.com/google/skills) for more stable verions.

> [!NOTE]
> This repository is under active development.

## Installation

```bash
npx skills add vszal/skills
```

From the `npx install` command, you can select the specific skills from this
repo to install.

## Available Skills

| Skill | Description | Maturity |
| :--- | :--- | :--- |
| [**GKE ComputeClasses**](./gke-compute-classes) | Priority-based node provisioning and fallback management. | *Experimental* |
| [**GKE Cluster Autoscaler**](./gke-cluster-autoscaler) | Optimization, consolidation tuning, and debugging pending pods. | *Experimental* |
| [**GKE Storage**](./gke-storage) | Guidance on block, shared, and volume management for GKE. | *Experimental* |
| [**GKE Upgrades**](./gke-upgrades) | Strategy, rollout sequencing, and troubleshooting for Control Plane and node upgrades. | *Experimental* |
