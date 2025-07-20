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

#### Alternative: Use NodePort
```bash
# Temporarily use NodePort for testing
kubectl patch service frontend-external -n ecomm-prod -p '{"spec":{"type":"NodePort"}}'

# Get NodePort
kubectl get service frontend-external -n ecomm-prod

# Access via node IP
kubectl get nodes -o wide
```

---

### 4. Cluster Creation Failures

**Symptoms:**
- `eksctl create cluster` fails
- CloudFormation stack errors
- Network/VPC creation issues

**Solutions:**

#### Check AWS Quotas
```bash
# Check service quotas
aws service-quotas get-service-quota --service-code eks --quota-code L-1194D53C
aws service-quotas get-service-quota --service-code ec2 --quota-code L-1216C47A
```

#### Verify Permissions
```bash
# Check IAM permissions
aws iam get-user
aws iam list-attached-user-policies --user-name $(aws sts get-caller-identity --query 'Arn' --output text | cut -d'/' -f2)
```

#### Alternative Cluster Creation
```bash
# Create with basic configuration
eksctl create cluster \
  --name ecommerce-01-cluster \
  --region us-east-1 \
  --node-type m5.large \
  --nodes 2 \
  --managed
```

---

### 5. Pod ImagePullBackOff Errors

**Symptoms:**
- Pods stuck in `ImagePullBackOff`
- Cannot pull images from Google Container Registry
- Container image errors

**Solutions:**

#### Check Pod Details
```bash
# Check pod status
kubectl get pods -n ecomm-prod

# Describe failing pod
kubectl describe pod <pod-name> -n ecomm-prod

# Check events
kubectl get events -n ecomm-prod --field-selector reason=Failed
```

#### Network Connectivity Test
```bash
# Test connectivity from a node
kubectl run debug --image=busybox --rm -it --restart=Never -- nslookup us-docker.pkg.dev

# Check if nodes can reach internet
kubectl get nodes -o wide
```

---

### 6. High Resource Usage / Node Pressure

**Symptoms:**
- Pods stuck in `Pending` state
- `Insufficient cpu` or `Insufficient memory` errors
- Nodes at capacity

**Solutions:**

#### Check Resource Usage
```bash
# Check node resource usage
kubectl top nodes

# Check pod resource usage
kubectl top pods -n ecomm-prod

# Check resource requests/limits
kubectl describe pod <pod-name> -n ecomm-prod | grep -A5 "Requests"
```

#### Scale Cluster
```bash
# Add more nodes
eksctl scale nodegroup --cluster=ecommerce-01-cluster --name=workers --nodes=4 --region=us-east-1

# Or create new nodegroup
eksctl create nodegroup \
  --cluster ecommerce-01-cluster \
  --region us-east-1 \
  --name workers-large \
  --node-type m5.xlarge \
  --nodes 2
```

---

### 7. DNS Resolution Issues

**Symptoms:**
- Services cannot communicate
- `nslookup` fails inside pods
- Inter-service connectivity problems

**Solutions:**

#### Check CoreDNS
```bash
# Check CoreDNS pods
kubectl get pods -n kube-system -l k8s-app=kube-dns

# Check CoreDNS logs
kubectl logs -n kube-system -l k8s-app=kube-dns

# Test DNS resolution
kubectl run debug --image=busybox --rm -it --restart=Never -- nslookup kubernetes.default
```

#### Restart CoreDNS
```bash
# Restart CoreDNS
kubectl rollout restart deployment/coredns -n kube-system
```

---

### 8. AWS CLI Issues

**Symptoms:**
- `aws` commands fail
- `head: |: No such file or directory` errors
- Strange output from AWS CLI

**Solutions:**

#### Reset AWS CLI Configuration
```bash
# Clear AWS CLI cache
rm -rf ~/.aws/cli/cache

# Reconfigure AWS CLI
aws configure

# Test basic functionality
aws sts get-caller-identity
```

#### Use Full Path
```bash
# Use full path to avoid shell conflicts
/opt/homebrew/bin/aws eks list-clusters --region us-east-1
```

---

## 🔍 Diagnostic Commands

### Quick Health Check
```bash
# Check all resources
kubectl get all -n ecomm-prod

# Check cluster health
kubectl get nodes
kubectl get pods -A | grep -v Running

# Check LoadBalancer status
kubectl get services --all-namespaces --field-selector spec.type=LoadBalancer
```

### Detailed Diagnostics
```bash
# Check cluster info
kubectl cluster-info

# Check component status
kubectl get componentstatuses

# Check events (last 1 hour)
kubectl get events --all-namespaces --sort-by='.lastTimestamp' | tail -20

# Check resource quotas
kubectl describe quota -n ecomm-prod
```

### AWS Resource Check
```bash
# Check EKS cluster
aws eks describe-cluster --name ecommerce-01-cluster --region us-east-1

# Check LoadBalancers
aws elbv2 describe-load-balancers --region us-east-1

# Check Security Groups
aws ec2 describe-security-groups --region us-east-1 --filters "Name=group-name,Values=*ecommerce-01-cluster*"
```

## 🆘 Emergency Commands

### Force Clean Restart
```bash
# Delete all pods (they will be recreated)
kubectl delete pods --all -n ecomm-prod

# Restart all deployments
kubectl rollout restart deployment -n ecomm-prod
```

### Complete Reset
```bash
# Delete application completely
kubectl delete namespace ecomm-prod

# Redeploy
./deploy-to-aws-eks.sh
```

### Get Help
```bash
# Check logs
kubectl logs -f deployment/frontend -n ecomm-prod

# Get shell in pod
kubectl exec -it deployment/frontend -n ecomm-prod -- /bin/sh

# Port forward for local testing
kubectl port-forward service/frontend 8080:80 -n ecomm-prod
```

## 🔗 Useful Links

- **AWS EKS Troubleshooting**: https://docs.aws.amazon.com/eks/latest/userguide/troubleshooting.html
- **AWS Load Balancer Controller**: https://kubernetes-sigs.github.io/aws-load-balancer-controller/
- **Kubernetes Events**: https://kubernetes.io/docs/tasks/debug-application-cluster/debug-application-introspection/
- **EKS Service Quotas**: https://docs.aws.amazon.com/eks/latest/userguide/service-quotas.html

## 📞 Getting Support

1. **Check this guide first** for common solutions
2. **Run diagnostic commands** to gather information
3. **Check AWS Console** for resource status
4. **Review CloudTrail logs** for API errors
5. **Search AWS documentation** for specific error messages

**Remember**: Most issues are related to permissions, networking, or resource limits! 🎯 