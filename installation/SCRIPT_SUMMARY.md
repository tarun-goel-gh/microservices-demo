# 📋 Installation Scripts Summary

This document provides an overview of all installation scripts and their purposes.

## 🎯 **Master Scripts (Recommended)**

### **1. Complete Stack Deployment**
**File**: `deploy-complete-stack.sh`
**Purpose**: One-command deployment of complete stack (observability + application)
**Features**:
- ✅ **Automated orchestration**: Deploys observability framework first, then application
- ✅ **Multiple deployment types**: AWS and local deployment support
- ✅ **Flexible configuration**: External access, Istio, load generator options
- ✅ **Comprehensive verification**: Validates both observability and application
- ✅ **Production ready**: Handles all prerequisites and error conditions

**Usage**:
```bash
# AWS deployment with external access
./installation/deploy-complete-stack.sh

# Local deployment
./installation/deploy-complete-stack.sh --type local

# AWS with Istio
./installation/deploy-complete-stack.sh --type aws --enable-istio

# Custom namespace
./installation/deploy-complete-stack.sh --namespace my-app
```

### **2. Complete Stack Cleanup**
**File**: `cleanup-complete-stack.sh`
**Purpose**: One-command cleanup of complete stack
**Features**:
- ✅ **Smart detection**: Auto-detects deployment type (AWS vs local)
- ✅ **Flexible cleanup**: Clean up everything, app-only, or observability-only
- ✅ **Orphaned resource cleanup**: Removes PVs, PVCs, and load balancers
- ✅ **Safety features**: Confirmation prompts and verification
- ✅ **Comprehensive verification**: Ensures complete cleanup

**Usage**:
```bash
# Clean up everything (with confirmation)
./installation/cleanup-complete-stack.sh

# Clean up only application
./installation/cleanup-complete-stack.sh --type app-only

# Clean up without confirmation
./installation/cleanup-complete-stack.sh --confirm
```

---

## 🚀 **Individual Deployment Scripts**

### **1. AWS Observability Deployment (Production Ready)**
**File**: `deploy-aws-observability.sh`
**Purpose**: Complete AWS deployment with EKS cluster and observability framework
**Phases**:
- ✅ **Phase 1**: Deploy AWS resources (EKS cluster, IAM roles, Load Balancers)
- ✅ **Phase 2**: Deploy observability framework
- ✅ **Phase 3**: Verify installation and provide access URLs

**Features**:
- ✅ **Robust EKS wait**: Handles eksctl utils wait issues with fallback methods
- ✅ **Timeout protection**: Prevents infinite waiting with configurable timeouts
- ✅ **kubectl verification**: Ensures connectivity after cluster is ready
- ✅ **Error handling**: Comprehensive error checking and recovery

**Usage**:
```bash
chmod +x installation/deploy-aws-observability.sh
./installation/deploy-aws-observability.sh
```

**Timeline**: 15-20 minutes
**Cost**: ~$50-200/month

### **2. Online Boutique Deployment (Application)**
**File**: `deploy-online-boutique.sh`
**Purpose**: Deploy the complete online boutique microservices application
**Features**:
- ✅ Deploys 11 microservices (frontend, cart, payment, etc.)
- ✅ Supports multiple deployment methods (Kubernetes, Helm, Kustomize)
- ✅ Optional Istio service mesh integration
- ✅ Load generator for testing
- ✅ External access configuration
- ✅ RBAC and security setup

**Usage**:
```bash
chmod +x installation/deploy-online-boutique.sh
./installation/deploy-online-boutique.sh
```

**Options**:
```bash
./installation/deploy-online-boutique.sh --external-access
./installation/deploy-online-boutique.sh --method helm
./installation/deploy-online-boutique.sh --enable-istio
./installation/deploy-online-boutique.sh --namespace my-boutique
```

**Timeline**: 5-10 minutes
**Cost**: Cluster costs only

### **3. Local/Existing Cluster Observability**
**File**: `deploy-observability-enhanced-fixed.sh`
**Purpose**: Deploy observability framework to existing Kubernetes cluster
**Features**:
- ✅ Deploys all monitoring components
- ✅ Configures dashboards and data sources
- ✅ Validates deployments

**Usage**:
```bash
chmod +x installation/deploy-observability-enhanced-fixed.sh
./installation/deploy-observability-enhanced-fixed.sh
```

**Timeline**: 5-10 minutes
**Cost**: Cluster costs only

### **4. Quick Start (Streamlined)**
**File**: `quick-start.sh`
**Purpose**: Streamlined installation for local/existing clusters
**Features**:
- ✅ Prerequisites validation
- ✅ File validation
- ✅ CRD installation
- ✅ Complete deployment
- ✅ Health verification

**Usage**:
```bash
chmod +x installation/quick-start.sh
./installation/quick-start.sh
```

**Timeline**: 5-10 minutes

---

## 🧹 **Cleanup Scripts**

### **1. AWS Observability Cleanup (Complete)**
**File**: `cleanup-aws-observability.sh`
**Purpose**: Complete cleanup of AWS resources and observability framework
**Features**:
- ✅ Removes observability components
- ✅ Deletes EKS cluster and node groups
- ✅ Removes Load Balancers and EBS volumes
- ✅ Cleans up IAM roles and policies
- ✅ Verifies cleanup
- ✅ Shows cost savings

**Usage**:
```bash
chmod +x installation/cleanup-aws-observability.sh
./installation/cleanup-aws-observability.sh
```

### **2. Online Boutique Cleanup (Application)**
**File**: `cleanup-online-boutique.sh`
**Purpose**: Complete cleanup of online boutique microservices application
**Features**:
- ✅ Removes all microservices deployments
- ✅ Deletes namespace and all resources
- ✅ Cleans up persistent volumes and claims
- ✅ Removes RBAC resources
- ✅ Cleans up Istio resources (if applicable)
- ✅ Auto-detects deployment method (Kubernetes/Helm)

**Usage**:
```bash
chmod +x installation/cleanup-online-boutique.sh
./installation/cleanup-online-boutique.sh
```

**Options**:
```bash
./installation/cleanup-online-boutique.sh --force
./installation/cleanup-online-boutique.sh --namespace my-boutique
./installation/cleanup-online-boutique.sh --method helm
```

### **2. Validation Script**
**File**: `validate-observability.sh`
**Purpose**: Comprehensive validation of observability framework
**Features**:
- ✅ File existence validation
- ✅ YAML syntax validation
- ✅ Configuration validation
- ✅ Performance compliance check
- ✅ Detailed reporting

**Usage**:
```bash
chmod +x installation/validate-observability.sh
./installation/validate-observability.sh
```

---

## 📚 **Documentation Files**

### **1. Installation Guide**
**File**: `../INSTALLATION_GUIDE.md`
**Purpose**: Complete step-by-step installation guide
**Content**:
- Prerequisites and requirements
- AWS and local deployment options
- Post-installation verification
- Configuration updates
- Troubleshooting

### **2. Troubleshooting Guide**
**File**: `TROUBLESHOOTING.md`
**Purpose**: Common issues and solutions
**Content**:
- Pod startup issues
- Service connectivity problems
- Performance issues
- Configuration problems

### **3. AWS EKS Setup Guide**
**File**: `AWS-EKS-SETUP.md`
**Purpose**: Detailed AWS EKS setup instructions
**Content**:
- AWS account setup
- IAM configuration
- EKS cluster creation
- Best practices

### **4. Cleanup Guide**
**File**: `CLEANUP-GUIDE.md`
**Purpose**: Manual cleanup instructions
**Content**:
- Step-by-step cleanup process
- Resource verification
- Cost optimization tips

---

## 🎯 **Script Selection Guide**

### **For Complete Production Setup**
```bash
# 1. Deploy AWS infrastructure and observability
./installation/deploy-aws-observability.sh

# 2. Deploy online boutique application
./installation/deploy-online-boutique.sh --external-access

# 3. Cleanup when done
./installation/cleanup-online-boutique.sh
./installation/cleanup-aws-observability.sh
```

### **For Development/Local Testing**
```bash
# 1. Deploy observability framework
./installation/quick-start.sh

# 2. Deploy online boutique application
./installation/deploy-online-boutique.sh

# 3. Access application
kubectl port-forward -n online-boutique svc/frontend 8080:8080
```

### **For Application Only (Existing Cluster)**
```bash
# Deploy just the online boutique
./installation/deploy-online-boutique.sh --method helm

# Or with external access
./installation/deploy-online-boutique.sh --external-access
```

### **For Validation and Testing**
```bash
# Validate observability framework
./installation/validate-observability.sh

# Test application deployment
kubectl get pods -n online-boutique
```

---

## ⚙️ **Configuration Files**

### **1. AWS Optimized Manifests**
**File**: `aws-optimized-manifests.yaml`
**Purpose**: AWS-specific Kubernetes manifests
**Content**:
- Storage class configurations
- Load Balancer annotations
- AWS-specific resource limits

### **2. Credentials and Keys**
**File**: `keys`, `ai_user_credentials.csv`
**Purpose**: Sample credentials and configuration
**Note**: Replace with actual credentials for production use

---

## 🔧 **Prerequisites by Script**

### **AWS Deployment Script**
- ✅ AWS CLI installed and configured
- ✅ eksctl installed
- ✅ kubectl installed
- ✅ Valid AWS credentials
- ✅ Sufficient AWS permissions

### **Local Deployment Scripts**
- ✅ kubectl installed
- ✅ Access to Kubernetes cluster
- ✅ Cluster resources available
- ✅ Storage class configured

### **Validation Script**
- ✅ kubectl installed
- ✅ Access to Kubernetes cluster
- ✅ All monitoring files present

---

## 📊 **Performance and Resource Requirements**

### **AWS Deployment**
- **EKS Cluster**: 3 t3.medium nodes (minimum)
- **Storage**: 50GB+ EBS volumes
- **Load Balancers**: 3 Network Load Balancers
- **Estimated Cost**: $50-200/month

### **Local Deployment**
- **CPU**: 4+ cores
- **Memory**: 8GB+ RAM
- **Storage**: 50GB+ available
- **Network**: Stable internet connection

---

## 🚨 **Important Notes**

### **Security Considerations**
- Update Alertmanager configuration with real webhook URLs
- Configure proper RBAC for production use
- Set up network policies for security
- Use secrets management for sensitive data

### **Cost Optimization**
- Use Spot instances for cost savings
- Implement data retention policies
- Monitor resource usage
- Clean up unused resources

### **Production Readiness**
- Test in non-production environment first
- Configure proper alert channels
- Set up monitoring for the monitoring stack
- Implement backup and recovery procedures

---

## 🎉 **Quick Start Commands**

### **Complete Production Setup (AWS + Application)**
```bash
# 1. Deploy AWS infrastructure and observability
./installation/deploy-aws-observability.sh

# 2. Deploy online boutique application
./installation/deploy-online-boutique.sh --external-access

# 3. Access applications
kubectl get svc -n monitoring  # Observability URLs
kubectl get svc -n online-boutique  # Application URLs

# 4. Cleanup when done
./installation/cleanup-online-boutique.sh
./installation/cleanup-aws-observability.sh
```

### **Local Development Setup**
```bash
# 1. Deploy observability framework
./installation/quick-start.sh

# 2. Deploy online boutique application
./installation/deploy-online-boutique.sh

# 3. Access applications
kubectl port-forward -n monitoring svc/grafana-service 3000:3000  # Grafana
kubectl port-forward -n online-boutique svc/frontend 8080:8080    # Boutique

# 4. Cleanup
kubectl delete namespace online-boutique
kubectl delete namespace monitoring
```

### **Application Only (Existing Cluster)**
```bash
# 1. Deploy online boutique
./installation/deploy-online-boutique.sh --external-access

# 2. Access application
kubectl get svc frontend -n online-boutique

# 3. Cleanup
./installation/cleanup-online-boutique.sh
```

All scripts are production-ready and include comprehensive error handling, validation, and documentation. 