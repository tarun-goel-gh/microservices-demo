# 🗑️ Cleanup Guide for Microservices Demo on AWS EKS

## 🚀 Quick Cleanup (Recommended)

Use the automated cleanup script:

```bash
cd microservices-demo
chmod +x undeploy-from-aws-eks.sh
./undeploy-from-aws-eks.sh
```

## 📋 Cleanup Options

### Option 1: Delete Application Only 
**Saves ~$50-100/month | Keeps cluster running**

```bash
# Using the script (recommended)
./undeploy-from-aws-eks.sh  # Choose option 1

# Manual commands
kubectl delete namespace ecomm-prod
```

**Good for:**
- Testing other applications on the same cluster
- Keeping cluster infrastructure for future use
- Partial cost reduction

---

### Option 2: Delete Application + Load Balancer Controller
**Saves ~$60-120/month | Clean cluster state**

```bash
# Using the script (recommended) 
./undeploy-from-aws-eks.sh  # Choose option 2

# Manual commands
kubectl delete namespace ecomm-prod
helm uninstall aws-load-balancer-controller -n kube-system
```

**Good for:**
- Clean slate for new deployments
- Removing all microservices-demo traces

---

### Option 3: Delete Everything (Complete Cleanup)
**Saves ~$400-550/month | Maximum savings**

```bash
# Using the script (recommended)
./undeploy-from-aws-eks.sh  # Choose option 3

# Manual commands
kubectl delete namespace ecomm-prod
eksctl delete cluster --name ecommerce-01-cluster --region us-east-1
```

**Good for:**
- Maximum cost savings
- No longer need Kubernetes cluster
- Complete cleanup

---

## 💰 Cost Breakdown

| Resource | Monthly Cost | Included In |
|----------|--------------|-------------|
| EKS Control Plane | ~$73 | All options with cluster |
| Worker Nodes (3x m6a.xlarge) | ~$300-400 | All options with cluster |
| Load Balancers | ~$20-40 | Deleted in all options |
| Data Transfer | ~$10-50 | Varies by usage |
| **Total** | **~$400-550** | **Full cleanup savings** |

## 🔍 Manual Verification Commands

### Check Remaining Resources
```bash
# Check namespaces
kubectl get namespaces

# Check pods in all namespaces
kubectl get pods --all-namespaces

# Check services
kubectl get services --all-namespaces

# Check LoadBalancer services specifically
kubectl get services --all-namespaces --field-selector spec.type=LoadBalancer
```

### Check AWS Resources
```bash
# Check EKS clusters
aws eks list-clusters --region us-east-1

# Check LoadBalancers
aws elbv2 describe-load-balancers --region us-east-1

# Check Security Groups
aws ec2 describe-security-groups --region us-east-1 --filters "Name=group-name,Values=*ecommerce-01-cluster*"
```

## 🆘 Emergency Cleanup Commands

If the automated script fails, use these manual commands:

### Force Delete Stuck Namespace
```bash
kubectl patch namespace ecomm-prod -p '{"metadata":{"finalizers":null}}'
kubectl delete namespace ecomm-prod --force --grace-period=0
```

### Force Delete Stuck Pods
```bash
kubectl delete pods --all -n ecomm-prod --force --grace-period=0
```

### Manual LoadBalancer Cleanup
```bash
# List LoadBalancers
aws elbv2 describe-load-balancers --region us-east-1 --query 'LoadBalancers[?contains(LoadBalancerName, `k8s`)].LoadBalancerArn'

# Delete LoadBalancer (replace ARN)
aws elbv2 delete-load-balancer --load-balancer-arn <LOAD_BALANCER_ARN>
```

### Emergency Cluster Deletion
```bash
# If eksctl fails, delete via AWS CLI
aws eks delete-cluster --name ecommerce-01-cluster --region us-east-1

# Delete node groups first if needed
aws eks delete-nodegroup --cluster-name ecommerce-01-cluster --nodegroup-name workers --region us-east-1
```

## 🔗 Useful Links

- **AWS EKS Console**: https://console.aws.amazon.com/eks/home?region=us-east-1#/clusters
- **AWS EC2 LoadBalancers**: https://console.aws.amazon.com/ec2/v2/home?region=us-east-1#LoadBalancers:
- **AWS Billing Dashboard**: https://console.aws.amazon.com/billing/home

## ⚠️ Important Notes

1. **LoadBalancer Deletion**: May take 5-10 minutes to complete
2. **Cluster Deletion**: Takes 10-15 minutes via eksctl
3. **Cost Impact**: Resources continue billing until fully deleted
4. **Backup**: No automatic backup - ensure you have deployment scripts
5. **Network**: VPC and subnets created by eksctl will be deleted with cluster

## 📞 Support

If you encounter issues during cleanup:

1. Check the script output for specific error messages
2. Use the manual verification commands above
3. Check AWS Console for resource status
4. Review AWS CloudTrail for API call errors

Remember: **AWS charges continue until resources are fully deleted!** 💸 