# 🚀 Installation Scripts Overview

This directory contains all installation scripts for the microservices demo application and observability framework.

## 📋 **Script Categories**

### **1. Deployment Scripts**
- `deploy-aws-observability.sh` - Complete AWS deployment with EKS and observability
- `deploy-online-boutique.sh` - Deploy the online boutique microservices application
- `deploy-observability-enhanced-fixed.sh` - Local observability framework deployment
- `quick-start.sh` - Streamlined local deployment

### **2. Cleanup Scripts**
- `cleanup-aws-observability.sh` - Complete AWS cleanup
- `cleanup-online-boutique.sh` - Application cleanup

### **3. Validation Scripts**
- `validate-observability.sh` - Comprehensive observability validation
- `test-eks-wait.sh` - EKS functionality testing

### **4. Documentation**
- `SCRIPT_SUMMARY.md` - Complete script overview and usage guide
- `TROUBLESHOOTING.md` - Common issues and solutions

## 🎯 **Recommended Installation Sequence**

### **Option 1: Complete Production Setup (AWS)**
```bash
# 1. Deploy AWS infrastructure + observability
./installation/deploy-aws-observability.sh

# 2. Deploy online boutique application
./installation/deploy-online-boutique.sh --external-access

# 3. Verify installation
./installation/validate-observability.sh

# 4. Cleanup when done
./installation/cleanup-online-boutique.sh
./installation/cleanup-aws-observability.sh
```

### **Option 2: Local Development Setup**
```bash
# 1. Deploy observability framework
./installation/quick-start.sh

# 2. Deploy online boutique application
./installation/deploy-online-boutique.sh

# 3. Verify installation
./installation/validate-observability.sh

# 4. Access applications
kubectl port-forward -n monitoring svc/grafana-service 3000:3000 &
kubectl port-forward -n online-boutique svc/frontend 8080:8080 &
```

### **Option 3: Application Only**
```bash
# Deploy just the online boutique
./installation/deploy-online-boutique.sh --external-access

# Cleanup
./installation/cleanup-online-boutique.sh
```

## 📚 **Documentation**

- `SCRIPT_SUMMARY.md` - Detailed script descriptions and usage
- `TROUBLESHOOTING.md` - Common issues and solutions
- `../docs/INSTALLATION_GUIDE.md` - Complete installation guide
- `../docs/ONLINE_BOUTIQUE_INSTALLATION.md` - Application-specific guide
- `../docs/COMPLETE_INSTALLATION_FLOW.md` - End-to-end installation flow

## 🔧 **Prerequisites**

### **For AWS Deployment**
- AWS CLI installed and configured
- eksctl installed
- kubectl installed
- Valid AWS credentials with EKS permissions

### **For Local Deployment**
- kubectl installed
- Access to Kubernetes cluster
- Helm (optional, for Helm deployments)

## ⚠️ **Security Notes**

- Remove any sensitive files (SSH keys, credentials) before sharing
- Update configuration files with your own values
- Use proper RBAC and network policies in production
- Configure secrets management for sensitive data

## 🎉 **Quick Start**

```bash
# Test EKS functionality (for AWS deployments)
./installation/test-eks-wait.sh

# Deploy everything to AWS
./installation/deploy-aws-observability.sh
./installation/deploy-online-boutique.sh --external-access

# Access your applications
kubectl get svc -n monitoring -o wide
kubectl get svc -n online-boutique -o wide
```

For detailed instructions, see the individual script documentation and guides. 