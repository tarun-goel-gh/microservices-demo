# 🚀 Microservices Demo on AWS EKS Setup Guide

This guide helps you deploy Google's [microservices-demo](https://github.com/GoogleCloudPlatform/microservices-demo) (Online Boutique) on AWS EKS.

## ⚡ Quick Start (2 Steps)

**Don't have an EKS cluster? No problem!** The script creates everything for you:

```bash
# 1. Configure AWS credentials (if not done already)
aws configure

# 2. Run the all-in-one deployment script
cd microservices-demo
./deploy-to-aws-eks.sh
```

That's it! The script will:
- 🔍 Check for existing clusters or create a new one (15-20 min)
- 📦 Install all prerequisites automatically  
- 🚀 Deploy the 11-service microservices application
- 🌐 Set up AWS Load Balancer for external access
- 💰 Estimated cost: ~$150-300/month for the cluster

> **💡 Having issues?** Check the [Troubleshooting Guide](TROUBLESHOOTING.md) for common solutions!

## 📋 What You'll Deploy

**Online Boutique** is a cloud-native microservices demo application consisting of 11 services:

- **Frontend** (Go) - Web UI
- **Cart Service** (C#) - Shopping cart management  
- **Product Catalog** (Go) - Product listings
- **Currency Service** (Node.js) - Currency conversion
- **Payment Service** (Node.js) - Payment processing
- **Shipping Service** (Go) - Shipping cost calculation
- **Email Service** (Python) - Order confirmation emails
- **Checkout Service** (Go) - Order processing
- **Recommendation Service** (Python) - Product recommendations
- **Ad Service** (Java) - Contextual ads
- **Load Generator** (Python/Locust) - Traffic simulation

## 🎯 Prerequisites

### 1. AWS Account & Credentials
You need an AWS account with appropriate permissions. Configure your AWS credentials:

```bash
# Configure AWS credentials (if not already done)
aws configure
```

### 2. Required Tools (Auto-installed)
The deployment script automatically installs these tools if missing:
- ✅ kubectl
- ✅ Helm 3
- ✅ AWS CLI  
- ✅ eksctl

### 3. EKS Cluster (Auto-created)
**No existing cluster needed!** The script will:
- ✅ Check for existing clusters in your region
- ✅ Let you choose an existing cluster OR
- ✅ Create a new cluster automatically

**Manual cluster creation (optional):**
```bash
# Only if you want to create cluster manually first
eksctl create cluster \
  --name microservices-demo-cluster \
  --region us-east-1 \
  --nodegroup-name workers \
  --node-type m5.large \
  --nodes 3 \
  --nodes-min 2 \
  --nodes-max 4 \
  --managed
```

## 🚀 Deployment Options

### Option 1: One-Command Deploy (Recommended)

**The deploy script now handles everything - cluster creation, prerequisites, and app deployment:**

```bash
cd microservices-demo
chmod +x deploy-to-aws-eks.sh
./deploy-to-aws-eks.sh
```

This script will:
- ✅ Check for existing EKS clusters
- ✅ Create a new cluster if none exists (takes 15-20 minutes)  
- ✅ Install prerequisites (kubectl, helm, eksctl)
- ✅ Deploy the microservices-demo with AWS optimizations
- ✅ Optionally install AWS Load Balancer Controller

### Option 2: Manual Helm Deploy

**If you already have a cluster configured:**
```bash
# Create namespace
kubectl create namespace microservices-demo

# Deploy with Helm
helm upgrade onlineboutique oci://us-docker.pkg.dev/online-boutique-ci/charts/onlineboutique \
    --install \
    --namespace microservices-demo \
    --set frontend.externalService=true \
    --set frontend.service.type=LoadBalancer \
    --set frontend.service.annotations."service\.beta\.kubernetes\.io/aws-load-balancer-type"="nlb" \
    --wait

# Set AWS platform
kubectl set env deployment/frontend ENV_PLATFORM=aws -n microservices-demo
```

### Option 2: Kubernetes Manifests

**Using pre-built release manifests:**

```bash
# Create namespace
kubectl create namespace microservices-demo

# Deploy the application
kubectl apply -f release/kubernetes-manifests.yaml -n microservices-demo

# Apply AWS optimizations
kubectl apply -f aws-optimized-manifests.yaml

# Patch frontend service for AWS
kubectl patch service frontend-external -n microservices-demo -p '{
    "metadata": {
        "annotations": {
            "service.beta.kubernetes.io/aws-load-balancer-type": "nlb",
            "service.beta.kubernetes.io/aws-load-balancer-cross-zone-load-balancing-enabled": "true"
        }
    }
}'
```

### Option 3: Kubernetes Manifests (Advanced)

```bash
# Create namespace
kubectl create namespace microservices-demo

# Deploy the application
kubectl apply -f release/kubernetes-manifests.yaml -n microservices-demo

# Apply AWS optimizations
kubectl apply -f aws-optimized-manifests.yaml
```

## 🔧 AWS-Specific Optimizations

Our deployment includes these AWS optimizations:

### Load Balancer Configuration
- **Network Load Balancer (NLB)** for better performance
- **Cross-zone load balancing** for high availability
- **Health checks** configured for the frontend service

### Platform Configuration
- **ENV_PLATFORM=aws** set on frontend service
- **AWS-optimized resource requests/limits**
- **Pod anti-affinity** for multi-AZ distribution (optional)

### Security
- **Service accounts** with least privilege
- **Security contexts** with non-root users
- **Network policies** available (optional)

## 📊 Monitoring Deployment

### Check Pod Status
```bash
# View all resources
kubectl get all -n microservices-demo

# Check pod status
kubectl get pods -n microservices-demo

# Watch pods come online
watch kubectl get pods -n microservices-demo
```

### Get Frontend URL
```bash
# Get LoadBalancer URL (may take 3-5 minutes)
kubectl get service frontend-external -n microservices-demo

# Or get it programmatically
FRONTEND_URL=$(kubectl get service frontend-external -n microservices-demo -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
echo "Frontend URL: http://$FRONTEND_URL"
```

### View Logs
```bash
# Frontend logs
kubectl logs -f deployment/frontend -n microservices-demo

# All services logs
kubectl logs -f -l app.kubernetes.io/name=onlineboutique -n microservices-demo
```

## 🎯 Accessing the Application

Once deployed, you can access the Online Boutique at the LoadBalancer URL:

1. **Get the URL:**
   ```bash
   kubectl get service frontend-external -n microservices-demo
   ```

2. **Open in browser:** `http://<EXTERNAL-IP>`

3. **Expected features:**
   - Browse products
   - Add items to cart
   - Checkout process
   - Recommendation engine
   - Load generation

## 🔨 Troubleshooting

### LoadBalancer Controller Timeout (Common Issue)

**If AWS Load Balancer Controller installation times out:**

```bash
# 1. Skip the controller and use Classic LoadBalancer (recommended)
./deploy-to-aws-eks.sh
# Choose option 2 when prompted

# 2. Or check controller status
kubectl get deployment -n kube-system aws-load-balancer-controller
kubectl logs -n kube-system deployment/aws-load-balancer-controller

# 3. Manual retry with longer timeout
helm uninstall aws-load-balancer-controller -n kube-system
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=ecommerce-01-cluster \
  --timeout=10m \
  --wait
```

### Other Common Issues

**Pods stuck in Pending:**
```bash
# Check node resources
kubectl describe nodes

# Check events
kubectl get events -n ecomm-prod --sort-by='.lastTimestamp'
```

**LoadBalancer stuck in Pending:**
```bash
# Check service events
kubectl describe service frontend-external -n ecomm-prod

# Try NodePort instead
kubectl patch service frontend-external -n ecomm-prod -p '{"spec":{"type":"NodePort"}}'
```

**Image pull errors:**
```bash
# Check if nodes can access Google's container registry
kubectl describe pod <pod-name> -n ecomm-prod
```

> **📚 For detailed troubleshooting:** See [TROUBLESHOOTING.md](TROUBLESHOOTING.md)

### Useful Commands

```bash
# Scale a service
kubectl scale deployment frontend --replicas=3 -n microservices-demo

# Update an environment variable
kubectl set env deployment/frontend ENABLE_PROFILER=1 -n microservices-demo

# Port forward for local testing
kubectl port-forward service/frontend 8080:80 -n microservices-demo

# Delete everything
kubectl delete namespace microservices-demo
```

## 💰 Cost Optimization

### Resource Limits
All services have resource requests/limits configured:
- **CPU requests:** 100-300m per service
- **Memory requests:** 64-256Mi per service  
- **Total cluster:** ~2-4 vCPUs, ~4-8GB RAM

### Cluster Sizing
**Recommended node configuration:**
- **Node type:** m5.large or m5.xlarge
- **Min nodes:** 2 (for HA)
- **Max nodes:** 10 (for autoscaling)
- **Total cost:** ~$150-300/month depending on usage

### Cleanup
```bash
# Remove the application but keep cluster
kubectl delete namespace microservices-demo

# Remove entire cluster
eksctl delete cluster --name microservices-demo --region us-west-2
```

## 🎯 Production Considerations

### High Availability
- Deploy across multiple AZs
- Use managed services (RDS for Redis, etc.)
- Implement proper monitoring

### Security
- Enable network policies
- Use AWS IAM roles for service accounts (IRSA)
- Implement pod security policies

### Monitoring
- Use AWS CloudWatch Container Insights
- Implement distributed tracing
- Set up alerts for service health

### Scaling
- Configure Horizontal Pod Autoscaler (HPA)
- Use Cluster Autoscaler for nodes
- Implement circuit breakers

## 📚 Additional Resources

- [Official microservices-demo repo](https://github.com/GoogleCloudPlatform/microservices-demo)
- [AWS EKS Best Practices](https://aws.github.io/aws-eks-best-practices/)
- [AWS Load Balancer Controller](https://kubernetes-sigs.github.io/aws-load-balancer-controller/)
- [Kubernetes on AWS](https://kubernetes.io/docs/setup/production-environment/turnkey/aws/)

## 🆘 Support

If you encounter issues:

1. Check the [troubleshooting section](#troubleshooting)
2. Review AWS EKS cluster health
3. Verify networking and security group configurations
4. Check AWS service quotas and limits

---

🎉 **Enjoy exploring the microservices architecture with Online Boutique on AWS EKS!** 