# Autoscaler Skill Improvements for Next Session

Based on the evaluation of `gke-cluster-autoscaler` against the 20 scenarios, the following improvements need to be implemented:

## 1. Strict Acronym Enforcement
- **Issue:** The model leaked the acronym "NAP" in `eval-3` (Selector Mismatch).
- **Action:** Create a highly visible "CRITICAL RULES" section at the top of `SKILL.md` explicitly banning the acronyms `CA`, `NAP`, `NAC`, and `CCC`. Explain *why* (to maintain documentation consistency) rather than just saying "don't do it".

## 2. Spot Stockout Fallback
- **Issue:** In `eval-0`, the model failed to explicitly recommend an On-Demand fallback when Spot capacity was exhausted (`scale.up.error.out.of.resources`).
- **Action:** Add a "Spot Best Practices" rule to `ca-optimization.md` mandating that anytime Spot is recommended or debugged, an On-Demand fallback priority MUST be suggested.

## 3. Selector Translation (EKS to GKE)
- **Issue:** The model struggled to clearly articulate the difference between custom selectors (`machine-family`) and standard GKE node labels (`cloud.google.com/machine-family`).
- **Action:** Add a specific troubleshooting entry to `ca-debug.md` detailing common selector mismatches, specifically translating generic or AWS-style labels to GKE-native ComputeClass expectations.