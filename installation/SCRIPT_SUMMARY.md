# Installation Scripts Summary

This document provides an overview of all installation and deployment scripts in the microservices-demo project.

## 🚀 **Deployment Scripts**

### **Main Deployment Scripts**
- **`deploy-aws-observability.sh`** - Complete AWS observability framework deployment
  - Creates EKS cluster with proper IAM roles
  - Deploys Prometheus, Grafana, Loki, Tempo, Alertmanager
  - Configures AWS Load Balancer Controller
  - Supports Classic Load Balancer option
  - Handles CRD installation with server-side apply

- **`deploy-online-boutique.sh`** - Online boutique microservices application deployment
  - Deploys all microservices (frontend, backend, database)
  - Supports multiple deployment methods (kubectl, helm, istio)
  - Configurable external access and load balancer types
  - Includes load generator for testing

- **`deploy-complete-stack.sh`** - Orchestrates complete deployment
  - Deploys both observability framework and application
  - Configurable deployment options
  - Comprehensive verification and access information

- **`deploy-with-clb.sh`** - Classic Load Balancer demo deployment
  - Demonstrates Classic Load Balancer usage
  - Sample application with CLB configuration
  - Health checks and monitoring setup

## 🧹 **Cleanup Scripts**

### **AWS Cleanup Scripts**
- **`cleanup-aws-observability.sh`** - AWS observability framework cleanup
  - Deletes EKS cluster with proper waiting
  - Removes Load Balancers, EBS volumes, security groups
  - Cleans up VPC infrastructure if created by eksctl
  - Handles IAM resources and orphaned resources

- **`cleanup-all-aws.sh`** - Comprehensive AWS cleanup (recommended)
  - Deletes ALL AWS resources in proper order
  - Handles all Load Balancer types (ALB, NLB, CLB)
  - Removes VPC, NAT Gateways, Elastic IPs
  - Cleans up IAM roles, policies, service accounts
  - Verifies cleanup completion

### **Application Cleanup Scripts**
- **`cleanup-online-boutique.sh`** - Online boutique application cleanup
  - Removes application namespaces and resources
  - Cleans up persistent volumes and services
  - Configurable cleanup options

- **`cleanup-complete-stack.sh`** - Complete stack cleanup
  - Orchestrates cleanup of both application and infrastructure
  - Supports selective cleanup (app-only, observability-only, all)

## 🛠️ **Utility Scripts**

### **Installation Utilities**
- **`install-prometheus-crds.sh`** - Prometheus Operator CRD installation
  - Uses server-side apply to handle large CRDs
  - Avoids annotation size limit errors
  - Standalone CRD installation script

- **`test-load-balancer-deployment.sh`** - Load balancer deployment testing
  - Tests Helm availability and chart access
  - Validates kustomize paths
  - Verifies AWS Load Balancer Controller deployment readiness

## 📚 **Documentation**

### **Guides and Documentation**
- **`CLASSIC_LOAD_BALANCER_GUIDE.md`** - Comprehensive CLB usage guide
- **`TROUBLESHOOTING.md`** - Common issues and solutions
- **`SCRIPT_SUMMARY.md`** - This file, script overview
- **`INSTALLATION_SEQUENCE.md`** - Step-by-step installation guide
- **`../docs/REVIEW_SUMMARY.md`** - Project review and architecture summary
- **`README.md`** - Installation directory overview

## 🔑 **Configuration Files**

### **SSH Keys and Credentials**
- **`id_rsa_eks`** - SSH private key for EKS nodes
- **`id_rsa_eks.pub`** - SSH public key for EKS nodes
- **`keys`** - Additional key configuration
- **`ai_user_credentials.csv`** - User credentials template

## 🎯 **Usage Examples**

### **Complete Deployment**
```bash
# Deploy everything
./installation/deploy-complete-stack.sh --confirm

# Deploy with specific options
./installation/deploy-complete-stack.sh --deployment-type aws --external-access --enable-istio
```

### **Individual Deployments**
```bash
# Deploy observability only
./installation/deploy-aws-observability.sh --confirm

# Deploy application only
./installation/deploy-online-boutique.sh --external-access

# Deploy with Classic Load Balancer
./installation/deploy-aws-observability.sh --load-balancer-type clb
```

### **Cleanup Operations**
```bash
# Complete cleanup (recommended)
./installation/cleanup-all-aws.sh --confirm

# Selective cleanup
./installation/cleanup-complete-stack.sh --type app-only --confirm

# Force cleanup of orphaned resources
./installation/cleanup-all-aws.sh --force --confirm
```

## 🔧 **Script Features**

### **Common Features**
- ✅ **Command-line arguments** for configuration
- ✅ **Prerequisites checking** before execution
- ✅ **Error handling** and graceful failures
- ✅ **Progress feedback** with colored output
- ✅ **Verification steps** after deployment
- ✅ **Cleanup confirmation** for safety
- ✅ **Documentation** and help messages

### **AWS-Specific Features**
- ✅ **EKS cluster management** with proper waiting
- ✅ **IAM role and policy** creation
- ✅ **Load balancer configuration** (ALB, NLB, CLB)
- ✅ **VPC and networking** setup
- ✅ **Resource cleanup** in proper order
- ✅ **Orphaned resource** detection and removal

## 📋 **Removed Scripts**

The following obsolete scripts have been removed:
- ❌ `deploy-observability-enhanced-fixed.sh` - Superseded by `deploy-aws-observability.sh`
- ❌ `quick-start.sh` - Superseded by `deploy-aws-observability.sh`
- ❌ `test-eks-wait.sh` - Testing script, no longer needed
- ❌ `validate-observability.sh` - Validation integrated into main scripts

## 🎉 **Summary**

The installation directory now contains a streamlined set of scripts that provide:
- **Complete deployment** from zero to production-ready
- **Comprehensive cleanup** of all resources
- **Multiple deployment options** for different use cases
- **Robust error handling** and verification
- **Clear documentation** and usage examples

All scripts are production-ready and include proper error handling, validation, and cleanup capabilities.