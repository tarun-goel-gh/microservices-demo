# 🔧 Troubleshooting Guide for Microservices Demo on AWS EKS

## 🚨 Common Issues and Solutions

### 1. EKS Cluster Wait Issues

**Symptoms:**
- `eksctl utils wait --cluster $CLUSTER_NAME --region $REGION` fails
- "Command not found" or timeout errors
- Cluster creation appears stuck

**Root Cause:**
The `eksctl utils wait` command may not be available in all eksctl versions or may have different syntax.

**Solution:**
The deployment script now handles this automatically with multiple fallback methods:

```bash
# The script automatically:
# 1. Checks if eksctl utils wait is available
# 2. Falls back to AWS CLI status checks if needed
# 3. Uses manual polling with timeouts
# 4. Verifies kubectl connectivity
```

**Manual verification:**
```bash
# Test EKS functionality
./installation/test-eks-wait.sh

# Check cluster status manually
aws eks describe-cluster --name observability-cluster --region us-west-2 --query 'cluster.status'

# Check node group status manually
aws eks describe-nodegroup --cluster-name observability-cluster --nodegroup-name standard-workers --region us-west-2 --query 'nodegroup.status'
```

**If cluster creation is stuck:**
```bash
# Check CloudFormation stack status
aws cloudformation describe-stacks --stack-name eksctl-observability-cluster-cluster --region us-west-2

# Check EKS cluster status
aws eks describe-cluster --name observability-cluster --region us-west-2
```

**If eksctl commands fail with unknown flags:**
```bash
# Check eksctl version
eksctl version

# Update eksctl if needed
# For macOS: brew upgrade eksctl
# For Linux: Download latest from https://github.com/weaveworks/eksctl/releases

# The script now handles eksctl version compatibility automatically
```

**Common eksctl version issues:**
- `--force-update` flag not available in older versions
- `utils wait` command not available in older versions
- The deployment script now automatically detects and handles these issues

**Cluster existence handling:**
- The script automatically checks if the cluster already exists
- If cluster exists and is ACTIVE, it will use the existing cluster
- If cluster exists but is CREATING, it will wait for it to become active
- If cluster exists but is DELETING, it will exit with an error
- Use `--use-existing` flag to force using an existing cluster

**IAM Policy Issues:**
- `AWSLoadBalancerControllerIAMPolicy` may not exist in all regions/accounts
- The script now creates a custom IAM policy with required permissions
- If you encounter IAM policy issues, the script will create the policy automatically
- Use `--skip-load-balancer` flag to skip AWS Load Balancer Controller installation

**AWS Load Balancer Controller Deployment Issues:**
- Kustomize paths may fail due to repository structure changes
- The script now uses Helm as the primary deployment method
- If Helm fails, it falls back to manual deployment with kustomize
- If all methods fail, LoadBalancer services will not work, but NodePort/ClusterIP will still function
- Check that the service account exists: `kubectl get serviceaccount aws-load-balancer-controller -n kube-system`
- Verify the deployment: `kubectl get deployment aws-load-balancer-controller -n kube-system`

**Prometheus Operator CRD Issues:**
- CRDs may fail due to annotation size limits (262144 bytes)
- The script now uses server-side apply to handle large CRDs
- If CRD installation fails, basic monitoring will still work
- Advanced Prometheus features may be limited without CRDs
- Check CRD status: `kubectl get crd | grep monitoring.coreos.com`
- Manual CRD installation: Use `kubectl apply --server-side -f <crd-file>`

**Tempo Deployment Port Name Issues:**
- Tempo deployment may fail due to port names exceeding 15 characters
- Kubernetes restricts port names to maximum 15 characters
- Fixed port names: `jaeger-thrift-compact` → `jaeger-compact`, `jaeger-thrift-binary` → `jaeger-binary`
- Affects both Tempo and OpenTelemetry Collector deployments
- Error: "Invalid value: must be no more than 15 characters"
- Solution: Updated monitoring/tempo-deployment.yaml and monitoring/otel-collector-deployment.yaml

**YAML Syntax Errors:**
- YAML files may have syntax errors causing deployment failures
- Common issues: missing spaces after colons, incorrect indentation
- Error: "error converting YAML to JSON: yaml: line X: could not find expected ':'"
- Fixed kube-state-metrics.yaml: `initialDelaySeconds:5` → `initialDelaySeconds: 5`
- Validation: All monitoring YAML files have been validated and are syntactically correct
- Check YAML syntax: `kubectl apply --dry-run=client -f <file.yaml>`

**Service Name Mismatches:**
- Deployment scripts may reference incorrect service names
- Error: "Error from server (NotFound): services 'grafana-service' not found"
- Fixed service names in deployment scripts:
  - `grafana-service` → `grafana`
  - `prometheus-service` → `prometheus`
  - `alertmanager-service` → `alertmanager`
- Affects: deploy-aws-observability.sh, deploy-complete-stack.sh
- Solution: Updated all service references to match actual YAML service names

**Missing ConfigMap Issues:**
- Deployments may fail due to missing ConfigMaps that are mounted as volumes
- Error: "MountVolume.SetUp failed for volume 'prometheus-rules': configmap 'prometheus-rules' not found"
- Fixed missing ConfigMaps:
  - **prometheus-rules** - Added prometheus-rules.yaml to deployment script
  - **observability-dashboard** - Added observability-dashboard-configmap.yaml to deployment script
  - **microservices-dashboard** - Already defined inline in grafana-deployment.yaml
  - **loki-config** - Fixed name mismatch: deployment expected 'loki-config', config creates 'loki-config-enhanced'
- Affects: Prometheus, Grafana, Loki deployments trying to mount ConfigMaps
- Solution: Added missing ConfigMap files to required files and deployment sequence, fixed ConfigMap name mismatches
- Check ConfigMap existence: `kubectl get configmap -n monitoring`

**ConfigMap Name Mismatches:**
- Deployments may reference ConfigMaps with different names than what's actually created
- Error: "MountVolume.SetUp failed for volume 'loki-config': configmap 'loki-config' not found"
- Root cause: Deployment expects one name, ConfigMap file creates another name
- Fixed ConfigMap name mismatches:
  - **Loki**: deployment expected 'loki-config', config creates 'loki-config-enhanced' → Updated deployment
- Solution: Ensure deployment ConfigMap references match actual ConfigMap names
- Check ConfigMap names: `kubectl get configmap -n monitoring -o name`

**PVC and ConfigMap Ordering Issues:**
- Deployments may fail due to PVCs and ConfigMaps not being created before deployments
- Error: "persistentvolumeclaim grafana-pvc not found" or "configmap grafana-dashboards not found"
- Root cause: Deployments try to mount volumes before PVCs/ConfigMaps are created
- Fixed by: Creating ConfigMaps before deploying main components
- Solution: Apply ConfigMaps first, then deployments (PVCs are defined in deployment files)
- Check PVC status: `kubectl get pvc -n monitoring`
- Check ConfigMap status: `kubectl get configmap -n monitoring`

**PVC Binding Issues:**
- Deployments may fail due to PVCs not being bound when pods try to use them
- Error: "error getting PVC monitoring/mimir-pvc: could not find v1.PersistentVolumeClaim"
- Root cause: Pods try to mount PVCs before they are fully bound
- Fixed by: Waiting for PVCs to be bound before waiting for deployments
- Solution: Added PVC binding wait in wait_for_deployments function
- Check PVC binding: `kubectl get pvc -n monitoring -o wide`

**Grafana Permission Issues:**
- Grafana pods may fail due to file permission issues with persistent volumes
- Error: "GF_PATHS_DATA='/var/lib/grafana' is not writable" or "Permission denied"
- Root cause: Grafana running as root but persistent volume has different permissions
- Fixed by: Adding security context to run as grafana user (UID 472)
- Solution: Added fsGroup, runAsUser, and runAsGroup to Grafana deployment
- Check Grafana logs: `kubectl logs <grafana-pod> -n monitoring`

**Configuration Parsing Errors:**
- Various components may fail due to YAML configuration parsing errors
- **Loki**: Duplicate fields and invalid frontend configuration
- **Mimir**: Invalid replication_factor and storage fields
- **Tempo**: Invalid fields in ingester and frontend configuration
- **Prometheus**: Permission denied errors with persistent volumes
- **Vector**: Image not found (wrong image tag)
- Fixed by: Cleaning up configuration files and updating image tags
- Solution: Removed duplicate/invalid fields, updated image references
- Check component logs: `kubectl logs <pod-name> -n monitoring`

**ServiceAccount Issues:**
- Deployments may fail due to ServiceAccount lookup errors
- Error: "error looking up service account monitoring/otel-collector: serviceaccount 'otel-collector' not found"
- Root cause: Namespace not fully ready when ServiceAccounts are created
- Fixed by: Ensuring namespace exists and adding propagation delay
- Affects: All deployments that use ServiceAccounts (otel-collector, vector, prometheus, etc.)
- Solution: Check namespace exists and add small delay before creating resources
- Check ServiceAccount existence: `kubectl get serviceaccount -n monitoring`

**Namespace Timeout Issues:**
- Namespace readiness checks may timeout unexpectedly
- Error: "timed out waiting for the condition on namespaces/monitoring"
- Root cause: kubectl wait --for=condition=Ready may not work reliably for namespaces
- Fixed by: Using simpler namespace existence check with kubectl get
- Solution: Check if namespace exists and add small propagation delay
- Check namespace status: `kubectl get namespace monitoring`

**Cleanup Issues:**
- EKS clusters may not be deleted properly due to dependency issues
- Use the comprehensive cleanup script: `./installation/cleanup-all-aws.sh`
- The script properly waits for cluster deletion and cleans up orphaned resources
- If cleanup fails, manually delete resources in this order:
  1. Delete Load Balancers first
  2. Delete EBS volumes
  3. Delete security groups
  4. Delete ENIs
  5. Delete NAT Gateways
  6. Delete VPC
- Check for orphaned resources: `aws ec2 describe-volumes --filters "Name=status,Values=available"`
- Force cleanup: `./installation/cleanup-all-aws.sh --force --confirm`

---

### 2. EKS Cluster RBAC Permission Denied

**Symptoms:**
- `apiservices.apiregistration.k8s.io is forbidden`
- `User "arn:aws:sts::xxx:assumed-role/..." cannot list resource`
- Cannot access cluster despite having AWS admin permissions

**Root Cause:**
Your AWS IAM role is not mapped to Kubernetes RBAC permissions in the cluster.

**Quick Fix:**
```bash
# Run the automated permission fix script
chmod +x fix-cluster-permissions.sh
./fix-cluster-permissions.sh

# Choose option 1 for automatic fix
```

**Manual Fix:**
```bash
# 1. Check your current AWS identity
aws sts get-caller-identity

# 2. Edit the aws-auth ConfigMap
kubectl edit configmap aws-auth -n kube-system

# 3. Add your role under mapRoles:
#   mapRoles: |
#     - rolearn: arn:aws:iam::ACCOUNT:role/AWSReservedSSO_AdministratorAccess_xxxxx
#       username: admin:{{SessionName}}
#       groups:
#         - system:masters

# 4. Save and wait 30 seconds for changes to take effect
```

**Alternative Solutions:**
- **Option A**: Create new cluster with your current role: `./deploy-to-aws-eks.sh`
- **Option B**: Switch to the AWS user/role that created the cluster
- **Option C**: Use different AWS profile with proper permissions

---

### 2. AWS Load Balancer Controller Installation Timeout

**Symptoms:**
- `helm install` timeout errors
- "waiting for deployment to be ready" stuck
- AWS Load Balancer Controller pods not starting

**Solutions:**

#### Quick Fix - Use Classic LoadBalancer
```bash
# Skip AWS Load Balancer Controller and use Classic ELB
./deploy-to-aws-eks.sh
# Choose option 2 when prompted for LoadBalancer type
```

#### Check Controller Status
```bash
# Check if controller is actually running
kubectl get deployment -n kube-system aws-load-balancer-controller

# Check pod logs
kubectl logs -n kube-system deployment/aws-load-balancer-controller

# Check events
kubectl get events -n kube-system --sort-by='.lastTimestamp'
```

#### Manual Installation
```bash
# Remove failed installation
helm uninstall aws-load-balancer-controller -n kube-system

# Install with longer timeout
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=ecommerce-01-cluster \
  --set serviceAccount.create=true \
  --set serviceAccount.name=aws-load-balancer-controller \
  --timeout=10m \
  --wait
```

---

### 3. LoadBalancer Stuck in Pending

**Symptoms:**
- `kubectl get services` shows LoadBalancer as `<pending>`
- Frontend URL not accessible
- LoadBalancer provisioning taking too long

**Solutions:**

#### Check Service Status
```bash
# Check service details
kubectl describe service frontend-external -n ecomm-prod

# Check events
kubectl get events -n ecomm-prod --sort-by='.lastTimestamp'
```

#### Verify Cluster Permissions
```bash
# Check if cluster has proper IAM permissions
aws sts get-caller-identity

# Check EKS cluster service role
aws eks describe-cluster --name ecommerce-01-cluster --region us-east-1 --query 'cluster.roleArn'
```