# GKE Autopilot Upgrades

## Autopilot vs Standard Upgrades
- **Autopilot Extended Duration:** While Standard GKE forcefully evicts pods after 1 hour (ignoring PDBs and grace periods), GKE Autopilot allows pods annotated with `cloud.google.com/extended-duration` to delay node upgrades for up to **7 days**.
- **Management:** In Autopilot, node upgrades are fully managed. Maintenance windows and exclusions are your primary tools for controlling upgrade timing.
- **Surge Upgrades:** Autopilot uses surge upgrades by default. Ensure your project has enough IP address space and Quota to create temporary additional nodes.