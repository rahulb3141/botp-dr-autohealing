# Simple Disaster Recovery Demo

A basic disaster recovery setup demonstrating:
- Multi-AZ EKS clusters in two regions
- Route 53 DNS failover capability
- S3 cross-region backup
- Kubernetes auto-healing with HPA
- Jenkins CI/CD pipeline for DR testing

## Quick Setup

1. **Setup Environment:**
   ```bash
   make setup
