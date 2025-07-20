# 🎯 **Complete Installation Sequence Guide**

This document outlines the recommended installation sequences for the microservices demo project.

## 📋 **Installation Requirements**

Based on your requirements, the installation should include:
1. ✅ **Deploy online-boutique services**
2. ✅ **Deploy Observability framework**
3. ✅ **Verify installation**
4. ✅ **Clean up scripts**

## 🚀 **Recommended Installation Sequences**

### **Sequence 1: Complete Production Setup (AWS) - RECOMMENDED**

**One-Command Deployment:**
```bash
# Deploy everything in the correct sequence
./installation/deploy-complete-stack.sh
```

**What this does:**
1. ✅ **Phase 1**: Deploy AWS infrastructure + observability framework
2. ✅ **Phase 2**: Deploy online boutique microservices application
3. ✅ **Phase 3**: Verify complete installation
4. ✅ **Result**: Production-ready stack with external access

**Cleanup:**
```bash
# Clean up everything
./installation/cleanup-complete-stack.sh
```

---

### **Sequence 2: Local Development Setup**

**One-Command Deployment:**
```bash
# Deploy to local/existing cluster
./installation/deploy-complete-stack.sh --type local
```

**What this does:**
1. ✅ **Phase 1**: Deploy observability framework to existing cluster
2. ✅ **Phase 2**: Deploy online boutique microservices application
3. ✅ **Phase 3**: Verify complete installation
4. ✅ **Result**: Development-ready stack with port-forwarding

**Cleanup:**
```bash
# Clean up everything
./installation/cleanup-complete-stack.sh
```

---

### **Sequence 3: Manual Step-by-Step (Advanced Users)**

**Step 1: Deploy Observability Framework**
```bash
# For AWS deployment
./installation/deploy-aws-observability.sh

# For local deployment
./installation/quick-start.sh
```

**Step 2: Deploy Online Boutique Application**
```bash
# Deploy with external access
./installation/deploy-online-boutique.sh --external-access

# Deploy with custom namespace
./installation/deploy-online-boutique.sh --namespace my-app --external-access
```

**Step 3: Verify Installation**
```bash
# Verify observability
./installation/validate-observability.sh

# Verify application
kubectl get pods -n online-boutique
kubectl get svc -n online-boutique
```

**Step 4: Cleanup (when done)**
```bash
# Clean up application
./installation/cleanup-online-boutique.sh

# Clean up observability
./installation/cleanup-aws-observability.sh
```

---

## 🎯 **Installation Options**

### **AWS Deployment Options**
```bash
# Basic AWS deployment
./installation/deploy-complete-stack.sh

# AWS with Istio service mesh
./installation/deploy-complete-stack.sh --enable-istio

# AWS with load generator
./installation/deploy-complete-stack.sh --enable-load-gen

# AWS with custom namespace
./installation/deploy-complete-stack.sh --namespace production-ecom
```

### **Local Deployment Options**
```bash
# Basic local deployment
./installation/deploy-complete-stack.sh --type local

# Local without external access
./installation/deploy-complete-stack.sh --type local --no-external-access

# Local with custom namespace
./installation/deploy-complete-stack.sh --type local --namespace dev-app
```

---

## 🔍 **Verification Steps**

### **Observability Verification**
```bash
# Run comprehensive validation
./installation/validate-observability.sh

# Check component status
kubectl get pods -n monitoring
kubectl get svc -n monitoring

# Test component connectivity
kubectl port-forward -n monitoring svc/grafana-service 3000:3000 &
# Open http://localhost:3000 (admin/admin)
```

### **Application Verification**
```bash
# Check application status
kubectl get pods -n online-boutique
kubectl get svc -n online-boutique

# Test application connectivity
kubectl port-forward -n online-boutique svc/frontend 8080:8080 &
# Open http://localhost:8080

# Test external access (if enabled)
kubectl get svc frontend -n online-boutique -o wide
```

---

## 🧹 **Cleanup Options**

### **Complete Cleanup**
```bash
# Clean up everything
./installation/cleanup-complete-stack.sh
```

### **Selective Cleanup**
```bash
# Clean up only application
./installation/cleanup-complete-stack.sh --type app-only

# Clean up only observability
./installation/cleanup-complete-stack.sh --type observability-only

# Clean up without confirmation
./installation/cleanup-complete-stack.sh --confirm
```

---

## 📊 **Timeline Estimates**

| Deployment Type | Time Estimate | Cost Estimate |
|----------------|---------------|---------------|
| **AWS Complete** | 20-30 minutes | $50-200/month |
| **Local Complete** | 10-15 minutes | Cluster costs only |
| **Application Only** | 5-10 minutes | Cluster costs only |
| **Observability Only** | 10-15 minutes | Cluster costs only |

---

## 🎯 **Quick Start Commands**

### **For Production (AWS)**
```bash
# Deploy everything
./installation/deploy-complete-stack.sh

# Access applications
kubectl get svc -n monitoring -o wide
kubectl get svc -n online-boutique -o wide

# Clean up when done
./installation/cleanup-complete-stack.sh
```

### **For Development (Local)**
```bash
# Deploy everything
./installation/deploy-complete-stack.sh --type local

# Access applications
kubectl port-forward -n monitoring svc/grafana-service 3000:3000 &
kubectl port-forward -n online-boutique svc/frontend 8080:8080 &

# Clean up when done
./installation/cleanup-complete-stack.sh
```

---

## ✅ **Success Criteria**

After successful installation, you should have:

### **Observability Framework**
- ✅ Prometheus metrics collection
- ✅ Grafana dashboards accessible
- ✅ Loki log aggregation
- ✅ Tempo distributed tracing
- ✅ Alertmanager alerting
- ✅ Vector log processing

### **Online Boutique Application**
- ✅ All 11 microservices running
- ✅ Frontend accessible
- ✅ Load balancer provisioned (if external access enabled)
- ✅ Service mesh configured (if Istio enabled)
- ✅ Load generator running (if enabled)

### **Integration**
- ✅ Application metrics visible in Prometheus
- ✅ Application logs visible in Loki
- ✅ Distributed traces visible in Tempo
- ✅ Custom dashboards available in Grafana

---

## 🆘 **Troubleshooting**

If you encounter issues:

1. **Check prerequisites**: Ensure kubectl, AWS CLI, and eksctl are installed
2. **Verify cluster access**: Run `kubectl cluster-info`
3. **Check AWS credentials**: Run `aws sts get-caller-identity`
4. **Review logs**: Check pod logs for specific errors
5. **Consult troubleshooting guide**: See `TROUBLESHOOTING.md`

For detailed troubleshooting, see the comprehensive troubleshooting guide in `TROUBLESHOOTING.md`. 