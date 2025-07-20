# 🚀 Observability Framework Installation Guide

This guide provides step-by-step instructions for installing the comprehensive observability framework on your Kubernetes cluster.

## 📋 **Prerequisites**

### **1. Kubernetes Cluster Requirements**
- **Kubernetes Version**: 1.20 or higher
- **Cluster Resources**: 
  - **CPU**: Minimum 4 cores, Recommended 8+ cores
  - **Memory**: Minimum 8GB RAM, Recommended 16GB+ RAM
  - **Storage**: Minimum 50GB, Recommended 100GB+ for data retention
- **Storage Class**: Default storage class configured
- **Network Policy**: CNI that supports NetworkPolicies (Calico, Cilium, etc.)

### **2. Tools Required**
```bash
# Install kubectl (if not already installed)
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl
sudo mv kubectl /usr/local/bin/

# Install helm (if not already installed)
curl https://get.helm.sh/helm-v3.12.0-linux-amd64.tar.gz | tar xz
sudo mv linux-amd64/helm /usr/local/bin/

# Install eksctl (for AWS deployment)
curl --silent --location "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp
sudo mv /tmp/eksctl /usr/local/bin

# Install AWS CLI (for AWS deployment)
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# Verify installations
kubectl version --client
helm version
eksctl version
aws --version
```

### **3. AWS Prerequisites (for AWS deployment)**
```bash
# Configure AWS credentials
aws configure

# Verify AWS access
aws sts get-caller-identity

# Set default region
aws configure set region us-west-2

# Test EKS functionality (optional)
./installation/test-eks-wait.sh
```

### **3. Cluster Access**
```bash
# Verify cluster access
kubectl cluster-info
kubectl get nodes
```

---

## 🔧 **Step 1: Pre-Installation Validation**

### **1.1 Run Validation Script**
```bash
# Make validation script executable
chmod +x installation/validate-observability.sh

# Run validation
./installation/validate-observability.sh
```

**Expected Output**: ✅ All validations should pass

### **1.2 Check Cluster Resources**
```bash
# Check available resources
kubectl top nodes
kubectl get nodes -o custom-columns="NAME:.metadata.name,CPU:.status.capacity.cpu,MEMORY:.status.capacity.memory"

# Check storage classes
kubectl get storageclass
```

### **1.3 Verify Required CRDs**
```bash
# Check if PrometheusRule CRD exists (required for alert rules)
kubectl get crd prometheusrules.monitoring.coreos.com

# If not found, install Prometheus Operator CRDs
kubectl apply -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/main/example/prometheus-operator-crd/monitoring.coreos.com_prometheusrules.yaml
```

---

## 🚀 **Step 2: Installation Options**

### **Option A: AWS Deployment (Recommended for Production)**

#### **2.1 Deploy to AWS EKS**
```bash
# Make AWS deployment script executable
chmod +x installation/deploy-aws-observability.sh

# Run AWS deployment
./installation/deploy-aws-observability.sh
```

**What the AWS script does**:
- ✅ **Phase 1**: Deploys AWS resources (EKS cluster, IAM roles, Load Balancers)
- ✅ **Phase 2**: Deploys complete observability framework
- ✅ **Phase 3**: Verifies installation and provides access URLs
- ✅ Creates production-ready infrastructure with external access
- ✅ Configures AWS Load Balancers for external access
- ✅ Sets up proper storage classes and IAM permissions

**Expected Timeline**: 15-20 minutes for complete AWS deployment

#### **2.2 Monitor AWS Deployment Progress**
```bash
# Watch EKS cluster creation
eksctl get cluster --name observability-cluster --region us-west-2

# Watch all pods in monitoring namespace
kubectl get pods -n monitoring -w

# Check Load Balancer provisioning
kubectl get svc -n monitoring -o wide
```

### **Option B: Local/Existing Cluster Deployment**

#### **2.3 Run the Enhanced Deployment Script**
```bash
# Make deployment script executable
chmod +x installation/deploy-observability-enhanced-fixed.sh

# Run automated installation
./installation/deploy-observability-enhanced-fixed.sh
```

**What the local script does**:
- ✅ Creates monitoring namespace
- ✅ Deploys core monitoring components (Prometheus, Grafana)
- ✅ Deploys logging stack (Loki, Vector, Promtail)
- ✅ Deploys tracing stack (Tempo, OpenTelemetry Collector)
- ✅ Deploys alerting stack (Alertmanager)
- ✅ Configures dashboards and data sources
- ✅ Validates all deployments

**Expected Timeline**: 5-10 minutes for complete installation

#### **2.4 Monitor Local Installation Progress**
```bash
# Watch all pods in monitoring namespace
kubectl get pods -n monitoring -w

# Check deployment status
kubectl get deployments -n monitoring
kubectl get services -n monitoring
```

---

## 🔧 **Step 3: Manual Installation (Alternative)**

If you prefer manual installation or need to customize specific components:

### **3.1 Create Namespace**
```bash
kubectl apply -f monitoring/namespace.yaml
```

### **3.2 Deploy Core Monitoring**
```bash
# Prometheus
kubectl apply -f monitoring/prometheus-config.yaml
kubectl apply -f monitoring/prometheus-deployment.yaml
kubectl apply -f monitoring/enhanced-prometheus-rules-fixed.yaml

# Grafana
kubectl apply -f monitoring/grafana-config.yaml
kubectl apply -f monitoring/grafana-deployment.yaml
kubectl apply -f monitoring/grafana-datasources.yaml
kubectl apply -f monitoring/grafana-dashboards.yaml
```

### **3.3 Deploy Logging Stack**
```bash
# Loki
kubectl apply -f monitoring/loki-config-enhanced.yaml
kubectl apply -f monitoring/loki-deployment.yaml

# Vector (Log Processing)
kubectl apply -f monitoring/vector-config-fixed.yaml
kubectl apply -f monitoring/vector-deployment.yaml

# Promtail (Log Collection)
kubectl apply -f monitoring/promtail-config.yaml
kubectl apply -f monitoring/promtail-daemonset.yaml
```

### **3.4 Deploy Tracing Stack**
```bash
# Tempo
kubectl apply -f monitoring/tempo-config.yaml
kubectl apply -f monitoring/tempo-deployment.yaml

# OpenTelemetry Collector
kubectl apply -f monitoring/otel-collector-config.yaml
kubectl apply -f monitoring/otel-collector-deployment.yaml
```

### **3.5 Deploy Alerting Stack**
```bash
# Alertmanager
kubectl apply -f monitoring/alertmanager-config.yaml
kubectl apply -f monitoring/alertmanager-deployment.yaml
kubectl apply -f monitoring/alertmanager-templates.yaml
```

### **3.6 Deploy Additional Components**
```bash
# Node Exporter
kubectl apply -f monitoring/node-exporter.yaml

# Kube State Metrics
kubectl apply -f monitoring/kube-state-metrics.yaml

# Mimir (Long-term metrics storage)
kubectl apply -f monitoring/mimir-config.yaml
kubectl apply -f monitoring/mimir-deployment.yaml
```

---

## ✅ **Step 4: Post-Installation Verification**

### **4.1 Check All Components**
```bash
# Verify all pods are running
kubectl get pods -n monitoring

# Expected output should show all pods in Running state:
# NAME                                    READY   STATUS    RESTARTS   AGE
# alertmanager-0                          1/1     Running   0          2m
# grafana-0                               1/1     Running   0          2m
# loki-0                                  1/1     Running   0          2m
# prometheus-0                            1/1     Running   0          2m
# tempo-0                                 1/1     Running   0          2m
# vector-0                                1/1     Running   0          2m
# ... (other components)
```

### **4.2 Verify Services**
```bash
# Check all services
kubectl get services -n monitoring

# Expected services:
# - alertmanager-service
# - grafana-service
# - loki-service
# - prometheus-service
# - tempo-service
# - vector-service
```

### **4.3 Test Component Health**
```bash
# Test Prometheus
kubectl port-forward -n monitoring svc/prometheus-service 9090:9090 &
curl http://localhost:9090/api/v1/status/config

# Test Grafana
kubectl port-forward -n monitoring svc/grafana-service 3000:3000 &
curl http://localhost:3000/api/health

# Test Loki
kubectl port-forward -n monitoring svc/loki-service 3100:3100 &
curl http://localhost:3100/ready

# Test Tempo
kubectl port-forward -n monitoring svc/tempo-service 3200:3200 &
curl http://localhost:3200/ready
```

---

## 🔧 **Step 5: Configuration Updates**

### **5.1 Update Alertmanager Configuration**
```bash
# Edit alertmanager config to replace placeholders
kubectl edit configmap alertmanager-config -n monitoring
```

**Replace these placeholders**:
- `YOUR_SLACK_WEBHOOK` → Your actual Slack webhook URL
- `YOUR_PAGERDUTY_KEY` → Your actual PagerDuty routing key
- `YOUR_EMAIL` → Your actual email address

### **5.2 Configure External Access**
```bash
# Create ingress for external access (if using ingress)
kubectl apply -f monitoring/ingress.yaml

# Or use LoadBalancer services
kubectl patch svc grafana-service -n monitoring -p '{"spec":{"type":"LoadBalancer"}}'
kubectl patch svc prometheus-service -n monitoring -p '{"spec":{"type":"LoadBalancer"}}'
```

### **5.3 Set Up Persistent Storage**
```bash
# Create PVCs for data persistence
kubectl apply -f monitoring/storage-pvc.yaml
```

---

## 📊 **Step 6: Application Integration**

### **6.1 Instrument Your Applications**
```bash
# Copy instrumentation files to your applications
cp src/frontend/metrics.go /path/to/your/app/
cp src/frontend/instrumentation.go /path/to/your/app/
```

### **6.2 Expose Metrics Endpoints**
Ensure your applications expose `/metrics` endpoints:
```go
// Example in your application
import "github.com/prometheus/client_golang/prometheus/promhttp"

// Add to your HTTP server
http.Handle("/metrics", promhttp.Handler())
```

### **6.3 Configure Service Discovery**
```bash
# Add service monitor for your applications
kubectl apply -f monitoring/service-monitors/
```

---

## 🔍 **Step 7: Verification and Testing**

### **7.1 Access Grafana Dashboard**
```bash
# Port forward Grafana
kubectl port-forward -n monitoring svc/grafana-service 3000:3000
```

**Access**: http://localhost:3000
- **Username**: admin
- **Password**: admin (change on first login)

### **7.2 Access Prometheus**
```bash
# Port forward Prometheus
kubectl port-forward -n monitoring svc/prometheus-service 9090:9090
```

**Access**: http://localhost:9090

### **7.3 Test Alerting**
```bash
# Trigger a test alert
kubectl port-forward -n monitoring svc/prometheus-service 9090:9090 &
curl -X POST http://localhost:9090/api/v1/admin/tsdb/snapshot
```

### **7.4 Verify Data Collection**
```bash
# Check metrics in Prometheus
# Query: up

# Check logs in Grafana
# Data source: Loki
# Query: {job="kubernetes-pods"}

# Check traces in Grafana
# Data source: Tempo
# Query: {service.name="your-service"}
```

---

## 🚨 **Step 8: Troubleshooting**

### **8.1 Common Issues**

**Pods not starting**:
```bash
# Check pod events
kubectl describe pod <pod-name> -n monitoring

# Check pod logs
kubectl logs <pod-name> -n monitoring
```

**Services not accessible**:
```bash
# Check service endpoints
kubectl get endpoints -n monitoring

# Check network policies
kubectl get networkpolicies -n monitoring
```

**Metrics not collecting**:
```bash
# Check Prometheus targets
kubectl port-forward svc/prometheus-service 9090:9090
# Visit: http://localhost:9090/targets
```

### **8.2 Performance Issues**
```bash
# Check resource usage
kubectl top pods -n monitoring

# Check storage usage
kubectl exec -it <pod-name> -n monitoring -- df -h
```

### **8.3 Get Help**
```bash
# Run troubleshooting script
./installation/TROUBLESHOOTING.md

# Check logs for all components
kubectl logs -l app=prometheus -n monitoring
kubectl logs -l app=grafana -n monitoring
kubectl logs -l app=loki -n monitoring
```

---

## 📈 **Step 9: Production Considerations**

### **9.1 Security Hardening**
```bash
# Enable RBAC
kubectl apply -f monitoring/rbac/

# Configure network policies
kubectl apply -f monitoring/network-policies/

# Set up secrets management
kubectl create secret generic alertmanager-secrets \
  --from-literal=slack-webhook="your-webhook" \
  --from-literal=pagerduty-key="your-key" \
  -n monitoring
```

### **9.2 Scaling Configuration**
```bash
# Scale components based on load
kubectl scale deployment prometheus -n monitoring --replicas=3
kubectl scale deployment loki -n monitoring --replicas=3
kubectl scale deployment vector -n monitoring --replicas=5
```

### **9.3 Backup and Recovery**
```bash
# Set up backup for persistent data
kubectl apply -f monitoring/backup/

# Configure data retention policies
kubectl edit configmap prometheus-config -n monitoring
```

---

## 🎯 **Installation Complete!**

Your observability framework is now installed and ready to use. The framework provides:

- ✅ **Comprehensive Monitoring**: Metrics, logs, and traces
- ✅ **Real-time Alerting**: Multi-channel alert delivery
- ✅ **Beautiful Dashboards**: Pre-configured Grafana dashboards
- ✅ **Scalable Architecture**: Horizontal scaling capabilities
- ✅ **ML-Ready**: Anomaly detection pipeline architecture
- ✅ **Production-Ready**: Security, backup, and recovery features

### **Quick Access URLs**:
- **Grafana**: http://localhost:3000 (admin/admin)
- **Prometheus**: http://localhost:9090
- **Alertmanager**: http://localhost:9093
- **Loki**: http://localhost:3100
- **Tempo**: http://localhost:3200

### **Next Steps**:
1. Configure your applications to expose metrics
2. Set up custom dashboards for your services
3. Configure alert channels for production use
4. Set up data retention policies
5. Monitor the monitoring stack itself

For additional help, refer to:
- `monitoring/OBSERVABILITY_FRAMEWORK.md` - Detailed architecture documentation
- `installation/TROUBLESHOOTING.md` - Troubleshooting guide
- `REVIEW_SUMMARY.md` - Complete review and fixes summary

---

## 🧹 **Cleanup and Removal**

### **AWS Deployment Cleanup**
```bash
# Clean up AWS resources and observability framework
./installation/cleanup-aws-observability.sh
```

**What the cleanup script does**:
- ✅ Removes all observability components
- ✅ Deletes EKS cluster and node groups
- ✅ Removes Load Balancers and EBS volumes
- ✅ Cleans up IAM roles and policies
- ✅ Verifies complete cleanup
- ✅ Shows cost savings information

### **Local Deployment Cleanup**
```bash
# Remove observability components only
kubectl delete namespace monitoring

# Or use the cleanup script
./installation/cleanup-monitoring.sh
```

### **Cost Considerations**
- **AWS EKS**: ~$0.10/hour for control plane + node costs
- **Load Balancers**: ~$0.0225/hour per Load Balancer
- **EBS Storage**: ~$0.08/GB-month
- **Data Transfer**: ~$0.09/GB outbound

**Estimated monthly cost**: $50-200 depending on usage and region 