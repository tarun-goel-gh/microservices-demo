# 🚀 Complete Installation Flow Guide

This guide provides the complete installation flow for both the observability framework and the online boutique microservices application.

## 📋 **Overview**

The complete setup includes:
1. **Observability Framework**: Monitoring, logging, tracing, and alerting
2. **Online Boutique Application**: 11 microservices demo application
3. **Integration**: Application monitoring and observability

---

## 🎯 **Installation Options**

### **Option 1: Complete Production Setup (AWS)**

#### **Step 1: Deploy AWS Infrastructure + Observability**
```bash
# Deploy complete AWS setup with observability
./installation/deploy-aws-observability.sh
```

**What this does**:
- ✅ Creates EKS cluster with proper IAM roles
- ✅ Deploys complete observability stack (Prometheus, Grafana, Loki, Tempo)
- ✅ Configures Load Balancers for external access
- ✅ Sets up storage and monitoring infrastructure

**Timeline**: 15-20 minutes
**Cost**: ~$50-200/month

#### **Step 2: Deploy Online Boutique Application**
```bash
# Deploy the microservices application
./installation/deploy-online-boutique.sh --external-access
```

**What this does**:
- ✅ Deploys 11 microservices (frontend, cart, payment, etc.)
- ✅ Configures external access via Load Balancer
- ✅ Sets up RBAC and security
- ✅ Integrates with observability framework

**Timeline**: 5-10 minutes

#### **Step 3: Access Your Applications**
```bash
# Get access URLs
kubectl get svc -n monitoring      # Observability URLs
kubectl get svc -n online-boutique # Application URLs
```

**Access URLs**:
- **Grafana Dashboard**: http://<grafana-lb> (admin/admin)
- **Online Boutique**: http://<frontend-lb>
- **Prometheus**: http://<prometheus-lb>
- **Alertmanager**: http://<alertmanager-lb>

### **Option 2: Local Development Setup**

#### **Step 1: Deploy Observability Framework**
```bash
# Deploy observability to existing cluster
./installation/quick-start.sh
```

#### **Step 2: Deploy Online Boutique Application**
```bash
# Deploy the microservices application
./installation/deploy-online-boutique.sh
```

#### **Step 3: Access Applications**
```bash
# Port forward to access applications
kubectl port-forward -n monitoring svc/grafana-service 3000:3000 &
kubectl port-forward -n online-boutique svc/frontend 8080:8080 &
```

**Access URLs**:
- **Grafana**: http://localhost:3000 (admin/admin)
- **Online Boutique**: http://localhost:8080

### **Option 3: Application Only (Existing Cluster)**

#### **Deploy Just the Application**
```bash
# Deploy online boutique with external access
./installation/deploy-online-boutique.sh --external-access

# Or use Helm
./installation/deploy-online-boutique.sh --method helm

# Or with Istio service mesh
./installation/deploy-online-boutique.sh --enable-istio
```

---

## 🔧 **Detailed Installation Steps**

### **Phase 1: Prerequisites**

#### **1.1 Install Required Tools**
```bash
# Install kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl && sudo mv kubectl /usr/local/bin/

# Install Helm (for Helm deployments)
curl https://get.helm.sh/helm-v3.12.0-linux-amd64.tar.gz | tar xz
sudo mv linux-amd64/helm /usr/local/bin/

# Install eksctl (for AWS deployments)
curl --silent --location "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp
sudo mv /tmp/eksctl /usr/local/bin

# Install AWS CLI (for AWS deployments)
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip && sudo ./aws/install
```

#### **1.2 Verify Cluster Access**
```bash
# Check cluster access
kubectl cluster-info
kubectl get nodes

# For AWS deployments, configure credentials
aws configure
aws sts get-caller-identity
```

### **Phase 2: Observability Framework**

#### **2.1 AWS Deployment (Production)**
```bash
# Deploy complete AWS observability stack
./installation/deploy-aws-observability.sh
```

**Components Deployed**:
- ✅ **EKS Cluster**: Managed Kubernetes cluster
- ✅ **Prometheus**: Metrics collection and storage
- ✅ **Grafana**: Visualization and dashboards
- ✅ **Loki**: Log aggregation and storage
- ✅ **Tempo**: Distributed tracing
- ✅ **Alertmanager**: Alert routing and notification
- ✅ **Vector**: High-performance log processing
- ✅ **Load Balancers**: External access

#### **2.2 Local Deployment (Development)**
```bash
# Deploy observability to existing cluster
./installation/quick-start.sh
```

**Components Deployed**:
- ✅ **Prometheus**: Metrics collection
- ✅ **Grafana**: Dashboards and visualization
- ✅ **Loki**: Log aggregation
- ✅ **Tempo**: Distributed tracing
- ✅ **Alertmanager**: Alert management

### **Phase 3: Online Boutique Application**

#### **3.1 Deploy Microservices**
```bash
# Deploy with default settings
./installation/deploy-online-boutique.sh

# Or with external access
./installation/deploy-online-boutique.sh --external-access

# Or using Helm
./installation/deploy-online-boutique.sh --method helm
```

**Microservices Deployed**:
- ✅ **Frontend**: Web UI (Go)
- ✅ **Product Catalog**: Product information (Go)
- ✅ **Cart Service**: Shopping cart (.NET Core)
- ✅ **Checkout Service**: Order processing (Go)
- ✅ **Payment Service**: Payment processing (Node.js)
- ✅ **Shipping Service**: Shipping calculations (Go)
- ✅ **Email Service**: Email notifications (Python)
- ✅ **Currency Service**: Currency conversion (Node.js)
- ✅ **Recommendation Service**: Product recommendations (Python)
- ✅ **Ad Service**: Advertisements (Java)
- ✅ **Load Generator**: Traffic generation (Python)

#### **3.2 Configure External Access**
```bash
# If using LoadBalancer
kubectl get svc frontend -n online-boutique

# If using port-forward
kubectl port-forward -n online-boutique svc/frontend 8080:8080
```

### **Phase 4: Integration and Monitoring**

#### **4.1 Configure Service Discovery**
```bash
# Create service monitors for the microservices
cat <<EOF | kubectl apply -f -
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: online-boutique-frontend
  namespace: monitoring
spec:
  selector:
    matchLabels:
      app: frontend
  endpoints:
  - port: http
    path: /metrics
EOF
```

#### **4.2 Set Up Custom Dashboards**
```bash
# Access Grafana
kubectl port-forward -n monitoring svc/grafana-service 3000:3000

# Import dashboards:
# 1. Go to http://localhost:3000 (admin/admin)
# 2. Import dashboard from monitoring/online-boutique-dashboard.json
# 3. Configure data sources (Prometheus, Loki, Tempo)
```

#### **4.3 Configure Alerts**
```bash
# Update Alertmanager configuration
kubectl edit configmap alertmanager-config -n monitoring

# Replace placeholders:
# - YOUR_SLACK_WEBHOOK → Your Slack webhook URL
# - YOUR_PAGERDUTY_KEY → Your PagerDuty routing key
# - YOUR_EMAIL → Your email address
```

---

## ✅ **Verification and Testing**

### **1. Verify Observability Stack**
```bash
# Check all monitoring components
kubectl get pods -n monitoring

# Test component health
kubectl port-forward -n monitoring svc/prometheus-service 9090:9090 &
curl http://localhost:9090/api/v1/status/config

kubectl port-forward -n monitoring svc/grafana-service 3000:3000 &
curl http://localhost:3000/api/health
```

### **2. Verify Application Deployment**
```bash
# Check all microservices
kubectl get pods -n online-boutique

# Test frontend connectivity
kubectl run test-frontend --image=curlimages/curl --rm -i --restart=Never -n online-boutique -- \
    curl -s http://frontend:8080/health

# Test service communication
kubectl run test-catalog --image=curlimages/curl --rm -i --restart=Never -n online-boutique -- \
    curl -s http://productcatalogservice:3550/health
```

### **3. Test Application Features**
```bash
# Access the application
kubectl port-forward -n online-boutique svc/frontend 8080:8080

# Open http://localhost:8080 in browser
# Test features:
# - Browse products
# - Add items to cart
# - Complete checkout process
# - View recommendations
```

---

## 🔍 **Monitoring and Observability**

### **1. Metrics Collection**
- **Application Metrics**: Request latency, throughput, error rates
- **Infrastructure Metrics**: CPU, memory, disk usage
- **Business Metrics**: Orders, revenue, user activity

### **2. Log Aggregation**
- **Application Logs**: Service logs with structured logging
- **Infrastructure Logs**: Kubernetes and system logs
- **Error Tracking**: Centralized error collection and analysis

### **3. Distributed Tracing**
- **Request Tracing**: End-to-end request flow tracking
- **Service Dependencies**: Service interaction mapping
- **Performance Analysis**: Latency breakdown by service

### **4. Alerting**
- **Infrastructure Alerts**: Resource usage, availability
- **Application Alerts**: Error rates, response times
- **Business Alerts**: Order failures, revenue drops

---

## 🧹 **Cleanup and Removal**

### **1. Complete Cleanup (Production)**
```bash
# Clean up application
./installation/cleanup-online-boutique.sh

# Clean up AWS infrastructure
./installation/cleanup-aws-observability.sh
```

### **2. Local Cleanup (Development)**
```bash
# Clean up application
kubectl delete namespace online-boutique

# Clean up observability
kubectl delete namespace monitoring
```

### **3. Partial Cleanup**
```bash
# Clean up specific components
kubectl delete deployment frontend -n online-boutique
kubectl delete svc frontend -n online-boutique

# Or use Helm
helm uninstall online-boutique -n online-boutique
```

---

## 🚨 **Troubleshooting**

### **1. Common Issues**

#### **Pods Not Starting**
```bash
# Check pod events
kubectl describe pod <pod-name> -n <namespace>

# Check pod logs
kubectl logs <pod-name> -n <namespace>

# Check resource usage
kubectl top pods -n <namespace>
```

#### **Services Not Accessible**
```bash
# Check service endpoints
kubectl get endpoints -n <namespace>

# Check service configuration
kubectl describe svc <service-name> -n <namespace>

# Test connectivity
kubectl run test-service --image=curlimages/curl --rm -i --restart=Never -n <namespace> -- \
    curl -s http://<service-name>:<port>/health
```

#### **Load Balancer Issues**
```bash
# Check Load Balancer status
kubectl get svc -n <namespace> -o wide

# Check Load Balancer events
kubectl describe svc <service-name> -n <namespace>
```

### **2. Performance Issues**
```bash
# Check resource usage
kubectl top pods -n <namespace>

# Scale deployments
kubectl scale deployment <deployment-name> --replicas=3 -n <namespace>

# Check resource limits
kubectl describe pod <pod-name> -n <namespace> | grep -A 10 "Limits:"
```

### **3. Monitoring Issues**
```bash
# Check Prometheus targets
kubectl port-forward svc/prometheus-service 9090:9090
# Visit http://localhost:9090/targets

# Check Grafana data sources
kubectl port-forward svc/grafana-service 3000:3000
# Visit http://localhost:3000/datasources
```

---

## 📈 **Scaling and Performance**

### **1. Horizontal Scaling**
```bash
# Scale application services
kubectl scale deployment frontend --replicas=5 -n online-boutique
kubectl scale deployment cartservice --replicas=3 -n online-boutique

# Scale monitoring components
kubectl scale deployment prometheus --replicas=3 -n monitoring
kubectl scale deployment loki --replicas=3 -n monitoring
```

### **2. Resource Optimization**
```bash
# Update resource limits
kubectl patch deployment frontend -n online-boutique -p '{
  "spec": {
    "template": {
      "spec": {
        "containers": [{
          "name": "server",
          "resources": {
            "requests": {"memory": "512Mi", "cpu": "500m"},
            "limits": {"memory": "1Gi", "cpu": "1000m"}
          }
        }]
      }
    }
  }
}'
```

### **3. Load Testing**
```bash
# Scale load generator
kubectl scale deployment loadgenerator --replicas=5 -n online-boutique

# Monitor performance
kubectl top pods -n online-boutique
kubectl logs -f deployment/loadgenerator -n online-boutique
```

---

## 🎯 **Production Considerations**

### **1. Security Hardening**
```bash
# Enable network policies
kubectl apply -f security/network-policies.yaml

# Configure RBAC
kubectl apply -f security/rbac.yaml

# Use secrets for sensitive data
kubectl create secret generic app-secrets \
    --from-literal=db-password="secure-password" \
    --from-literal=api-key="secure-api-key"
```

### **2. High Availability**
```bash
# Deploy with multiple replicas
kubectl scale deployment frontend --replicas=3 -n online-boutique
kubectl scale deployment cartservice --replicas=3 -n online-boutique

# Configure pod disruption budgets
kubectl apply -f ha/pod-disruption-budgets.yaml
```

### **3. Backup and Recovery**
```bash
# Backup application data
kubectl get all -n online-boutique -o yaml > backup/online-boutique-backup.yaml
kubectl get all -n monitoring -o yaml > backup/monitoring-backup.yaml

# Restore from backup
kubectl apply -f backup/online-boutique-backup.yaml
kubectl apply -f backup/monitoring-backup.yaml
```

---

## 🎉 **Installation Complete!**

Your complete microservices environment is now deployed and ready for use!

### **Quick Access URLs**:
- **Online Boutique**: http://localhost:8080 (or LoadBalancer URL)
- **Grafana Dashboard**: http://localhost:3000 (admin/admin)
- **Prometheus**: http://localhost:9090
- **Alertmanager**: http://localhost:9093

### **Next Steps**:
1. Explore the online boutique application
2. Configure custom dashboards in Grafana
3. Set up custom alerts for your use case
4. Configure custom domains and SSL certificates
5. Set up CI/CD pipelines for automated deployments
6. Implement security best practices

### **Useful Commands**:
```bash
# Check application status
kubectl get pods -n online-boutique
kubectl get pods -n monitoring

# View application logs
kubectl logs -f deployment/frontend -n online-boutique

# Monitor performance
kubectl top pods -n online-boutique
kubectl top pods -n monitoring

# Access applications
kubectl port-forward -n online-boutique svc/frontend 8080:8080
kubectl port-forward -n monitoring svc/grafana-service 3000:3000
```

For additional help, refer to:
- `docs/INSTALLATION_GUIDE.md` - Detailed observability installation
- `docs/ONLINE_BOUTIQUE_INSTALLATION.md` - Detailed application installation
- `installation/TROUBLESHOOTING.md` - Troubleshooting guide
- `monitoring/OBSERVABILITY_FRAMEWORK.md` - Observability architecture 