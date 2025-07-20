# 🛍️ Online Boutique Microservices Installation Guide

This guide provides step-by-step instructions for deploying the complete online boutique microservices application.

## 📋 **Overview**

The Online Boutique is a cloud-native microservices demo application that showcases modern application development practices. It consists of 11 microservices written in different languages and frameworks.

### **Microservices Architecture**

| Service | Language | Purpose | Port |
|---------|----------|---------|------|
| **Frontend** | Go | Web UI | 8080 |
| **Product Catalog** | Go | Product information | 3550 |
| **Cart Service** | .NET Core | Shopping cart | 7070 |
| **Checkout Service** | Go | Order processing | 5050 |
| **Payment Service** | Node.js | Payment processing | 50051 |
| **Shipping Service** | Go | Shipping calculations | 50051 |
| **Email Service** | Python | Email notifications | 8080 |
| **Currency Service** | Node.js | Currency conversion | 7000 |
| **Recommendation Service** | Python | Product recommendations | 8080 |
| **Ad Service** | Java | Advertisements | 9555 |
| **Load Generator** | Python | Traffic generation | 8089 |

---

## 🚀 **Quick Start**

### **Option 1: Simple Deployment**
```bash
# Deploy with default settings
./installation/deploy-online-boutique.sh

# Access the application
kubectl port-forward -n online-boutique svc/frontend 8080:8080
# Open http://localhost:8080
```

### **Option 2: Production Deployment**
```bash
# Deploy with external access
./installation/deploy-online-boutique.sh --external-access

# Get external URL
kubectl get svc frontend -n online-boutique
```

### **Option 3: Helm Deployment**
```bash
# Deploy using Helm
./installation/deploy-online-boutique.sh --method helm

# Access the application
kubectl port-forward -n online-boutique svc/frontend 8080:8080
```

---

## 📋 **Prerequisites**

### **1. Kubernetes Cluster**
- **Version**: 1.20 or higher
- **Resources**: 
  - **CPU**: Minimum 4 cores, Recommended 8+ cores
  - **Memory**: Minimum 8GB RAM, Recommended 16GB+ RAM
  - **Storage**: Minimum 20GB available

### **2. Tools Required**
```bash
# Install kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl
sudo mv kubectl /usr/local/bin/

# Install Helm (for Helm deployment)
curl https://get.helm.sh/helm-v3.12.0-linux-amd64.tar.gz | tar xz
sudo mv linux-amd64/helm /usr/local/bin/

# Install Kustomize (for Kustomize deployment)
curl -s "https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh" | bash
sudo mv kustomize /usr/local/bin/

# Verify installations
kubectl version --client
helm version
kustomize version
```

### **3. Cluster Access**
```bash
# Verify cluster access
kubectl cluster-info
kubectl get nodes
```

---

## 🔧 **Installation Options**

### **Option A: Kubernetes Manifests (Default)**

#### **1. Deploy Using Script**
```bash
# Make script executable
chmod +x installation/deploy-online-boutique.sh

# Deploy with default settings
./installation/deploy-online-boutique.sh
```

#### **2. Manual Deployment**
```bash
# Create namespace
kubectl create namespace online-boutique

# Deploy core services
kubectl apply -f kubernetes-manifests/productcatalogservice.yaml -n online-boutique
kubectl apply -f kubernetes-manifests/cartservice.yaml -n online-boutique
kubectl apply -f kubernetes-manifests/currencyservice.yaml -n online-boutique
kubectl apply -f kubernetes-manifests/emailservice.yaml -n online-boutique
kubectl apply -f kubernetes-manifests/paymentservice.yaml -n online-boutique
kubectl apply -f kubernetes-manifests/shippingservice.yaml -n online-boutique
kubectl apply -f kubernetes-manifests/checkoutservice.yaml -n online-boutique
kubectl apply -f kubernetes-manifests/recommendationservice.yaml -n online-boutique
kubectl apply -f kubernetes-manifests/adservice.yaml -n online-boutique

# Deploy frontend
kubectl apply -f kubernetes-manifests/frontend.yaml -n online-boutique

# Deploy load generator (optional)
kubectl apply -f kubernetes-manifests/loadgenerator.yaml -n online-boutique
```

### **Option B: Helm Deployment**

#### **1. Deploy Using Script**
```bash
# Deploy using Helm
./installation/deploy-online-boutique.sh --method helm
```

#### **2. Manual Helm Deployment**
```bash
# Deploy using Helm chart
helm install online-boutique ./helm-chart \
    --namespace online-boutique \
    --create-namespace

# Deploy with custom values
helm install online-boutique ./helm-chart \
    --namespace online-boutique \
    --create-namespace \
    --set loadGenerator.enabled=true \
    --set frontend.service.type=LoadBalancer
```

### **Option C: Kustomize Deployment**

#### **1. Deploy Using Script**
```bash
# Deploy using Kustomize
./installation/deploy-online-boutique.sh --method kustomize
```

#### **2. Manual Kustomize Deployment**
```bash
# Deploy using Kustomize
kubectl apply -k kustomize/base/ -n online-boutique

# Deploy with overlays
kubectl apply -k kustomize/overlays/production/ -n online-boutique
```

---

## ⚙️ **Configuration Options**

### **1. Command Line Options**
```bash
# Basic deployment
./installation/deploy-online-boutique.sh

# Custom namespace
./installation/deploy-online-boutique.sh --namespace my-boutique

# With external access
./installation/deploy-online-boutique.sh --external-access

# Using Helm
./installation/deploy-online-boutique.sh --method helm

# With Istio service mesh
./installation/deploy-online-boutique.sh --enable-istio

# Disable load generator
./installation/deploy-online-boutique.sh --disable-load-generator

# Disable monitoring hints
./installation/deploy-online-boutique.sh --disable-monitoring
```

### **2. Environment Variables**
```bash
# Set custom configuration
export BOUTIQUE_NAMESPACE="my-boutique"
export BOUTIQUE_METHOD="helm"
export BOUTIQUE_EXTERNAL_ACCESS="true"
export BOUTIQUE_ENABLE_ISTIO="true"

# Run deployment
./installation/deploy-online-boutique.sh
```

### **3. Helm Values Customization**
```yaml
# Create custom values file
cat <<EOF > custom-values.yaml
namespace: my-boutique
loadGenerator:
  enabled: true
  replicas: 2
frontend:
  service:
    type: LoadBalancer
  resources:
    requests:
      memory: "256Mi"
      cpu: "250m"
    limits:
      memory: "512Mi"
      cpu: "500m"
EOF

# Deploy with custom values
helm install online-boutique ./helm-chart \
    --namespace my-boutique \
    --create-namespace \
    --values custom-values.yaml
```

---

## ✅ **Post-Installation Verification**

### **1. Check Deployment Status**
```bash
# Check all pods
kubectl get pods -n online-boutique

# Check all services
kubectl get services -n online-boutique

# Check deployments
kubectl get deployments -n online-boutique
```

### **2. Test Application Connectivity**
```bash
# Test frontend connectivity
kubectl run test-frontend --image=curlimages/curl --rm -i --restart=Never -n online-boutique -- \
    curl -s http://frontend:8080/health

# Test internal service communication
kubectl run test-catalog --image=curlimages/curl --rm -i --restart=Never -n online-boutique -- \
    curl -s http://productcatalogservice:3550/health
```

### **3. Access the Application**
```bash
# Port forward to access frontend
kubectl port-forward -n online-boutique svc/frontend 8080:8080

# Access in browser: http://localhost:8080
```

---

## 🌐 **External Access Configuration**

### **1. LoadBalancer Access**
```bash
# Deploy with external access
./installation/deploy-online-boutique.sh --external-access

# Get external URL
kubectl get svc frontend -n online-boutique -o wide
```

### **2. Ingress Configuration**
```bash
# Create ingress for the application
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: online-boutique-ingress
  namespace: online-boutique
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  rules:
  - host: boutique.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: frontend
            port:
              number: 8080
EOF
```

### **3. Istio Gateway (if using Istio)**
```bash
# Deploy with Istio
./installation/deploy-online-boutique.sh --enable-istio

# Apply Istio gateway
kubectl apply -f istio-manifests/frontend-gateway.yaml -n online-boutique
kubectl apply -f istio-manifests/frontend.yaml -n online-boutique
```

---

## 📊 **Monitoring Integration**

### **1. Deploy Observability Framework**
```bash
# Deploy the observability framework
./installation/deploy-aws-observability.sh

# Or for local deployment
./installation/deploy-observability-enhanced-fixed.sh
```

### **2. Configure Service Discovery**
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

### **3. Set Up Custom Dashboards**
```bash
# Import online boutique dashboard to Grafana
kubectl port-forward -n monitoring svc/grafana-service 3000:3000
# Access Grafana at http://localhost:3000 (admin/admin)
# Import dashboard from monitoring/online-boutique-dashboard.json
```

---

## 🔍 **Troubleshooting**

### **1. Common Issues**

#### **Pods Not Starting**
```bash
# Check pod events
kubectl describe pod <pod-name> -n online-boutique

# Check pod logs
kubectl logs <pod-name> -n online-boutique

# Check resource usage
kubectl top pods -n online-boutique
```

#### **Services Not Accessible**
```bash
# Check service endpoints
kubectl get endpoints -n online-boutique

# Check service configuration
kubectl describe svc <service-name> -n online-boutique

# Test service connectivity
kubectl run test-service --image=curlimages/curl --rm -i --restart=Never -n online-boutique -- \
    curl -s http://<service-name>:<port>/health
```

#### **Frontend Not Loading**
```bash
# Check frontend logs
kubectl logs -f deployment/frontend -n online-boutique

# Check frontend service
kubectl describe svc frontend -n online-boutique

# Test frontend connectivity
kubectl run test-frontend --image=curlimages/curl --rm -i --restart=Never -n online-boutique -- \
    curl -s http://frontend:8080/health
```

### **2. Performance Issues**
```bash
# Check resource usage
kubectl top pods -n online-boutique

# Check resource limits
kubectl describe pod <pod-name> -n online-boutique | grep -A 10 "Limits:"

# Scale deployments if needed
kubectl scale deployment frontend --replicas=3 -n online-boutique
```

### **3. Database Issues**
```bash
# Check Redis connectivity (for cart service)
kubectl logs deployment/cartservice -n online-boutique | grep -i redis

# Check database connections
kubectl logs deployment/productcatalogservice -n online-boutique | grep -i database
```

---

## 🧹 **Cleanup and Removal**

### **1. Complete Cleanup**
```bash
# Clean up everything
./installation/cleanup-online-boutique.sh

# Or clean up without confirmation
./installation/cleanup-online-boutique.sh --force
```

### **2. Manual Cleanup**
```bash
# Delete namespace (removes everything)
kubectl delete namespace online-boutique

# Or delete individual resources
kubectl delete deployments --all -n online-boutique
kubectl delete services --all -n online-boutique
kubectl delete namespace online-boutique
```

### **3. Helm Cleanup**
```bash
# Uninstall Helm release
helm uninstall online-boutique -n online-boutique

# Delete namespace
kubectl delete namespace online-boutique
```

---

## 📈 **Scaling and Performance**

### **1. Horizontal Scaling**
```bash
# Scale frontend
kubectl scale deployment frontend --replicas=5 -n online-boutique

# Scale cart service
kubectl scale deployment cartservice --replicas=3 -n online-boutique

# Scale all services
kubectl scale deployment --all --replicas=3 -n online-boutique
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
kubectl apply -f security/network-policies.yaml -n online-boutique

# Configure RBAC
kubectl apply -f security/rbac.yaml -n online-boutique

# Use secrets for sensitive data
kubectl create secret generic boutique-secrets \
    --from-literal=db-password="secure-password" \
    --from-literal=api-key="secure-api-key" \
    -n online-boutique
```

### **2. High Availability**
```bash
# Deploy with multiple replicas
kubectl scale deployment frontend --replicas=3 -n online-boutique
kubectl scale deployment cartservice --replicas=3 -n online-boutique

# Configure pod disruption budgets
kubectl apply -f ha/pod-disruption-budgets.yaml -n online-boutique
```

### **3. Backup and Recovery**
```bash
# Backup application data
kubectl get all -n online-boutique -o yaml > backup/online-boutique-backup.yaml

# Restore from backup
kubectl apply -f backup/online-boutique-backup.yaml
```

---

## 🎉 **Installation Complete!**

Your online boutique microservices application is now deployed and ready to use!

### **Quick Access URLs**:
- **Frontend**: http://localhost:8080 (via port-forward)
- **External**: http://<load-balancer-ip> (if using LoadBalancer)
- **Internal**: http://frontend.online-boutique.svc.cluster.local:8080

### **Next Steps**:
1. Explore the application features
2. Deploy the observability framework for monitoring
3. Configure custom domains and SSL certificates
4. Set up CI/CD pipelines for automated deployments
5. Implement security best practices

### **Useful Commands**:
```bash
# Check application status
kubectl get pods -n online-boutique

# View application logs
kubectl logs -f deployment/frontend -n online-boutique

# Access application
kubectl port-forward -n online-boutique svc/frontend 8080:8080

# Monitor performance
kubectl top pods -n online-boutique
```

For additional help, refer to:
- `installation/TROUBLESHOOTING.md` - Troubleshooting guide
- `monitoring/OBSERVABILITY_FRAMEWORK.md` - Monitoring setup
- `README.md` - Application overview 