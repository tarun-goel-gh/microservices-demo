# Classic Load Balancer (CLB) Guide

## Overview

This guide explains how to use AWS Classic Load Balancers (CLB) instead of Network Load Balancers (NLB) or Application Load Balancers (ALB) for your microservices deployment.

## 🎯 **Why Use Classic Load Balancers?**

### **Advantages of CLB**
- ✅ **Simpler Configuration**: Less complex than ALB/NLB
- ✅ **Cost Effective**: Generally cheaper than NLB/ALB
- ✅ **Wide Compatibility**: Works with older AWS regions
- ✅ **TCP/SSL Support**: Native support for TCP and SSL termination
- ✅ **Health Checks**: Built-in health check capabilities
- ✅ **No AWS Load Balancer Controller Required**: Works without the controller

### **Use Cases for CLB**
- 🎯 **Simple HTTP/HTTPS traffic**
- 🎯 **TCP-based services**
- 🎯 **Cost-sensitive deployments**
- 🎯 **Legacy application support**
- 🎯 **Development and testing environments**

## 🚀 **Deployment Options**

### **1. Using the Deployment Script**

```bash
# Deploy with Classic Load Balancers
./installation/deploy-aws-observability.sh --load-balancer-type clb

# Deploy online boutique with Classic Load Balancers
./installation/deploy-online-boutique.sh --load-balancer-type clb
```

### **2. Manual Service Configuration**

```yaml
# Example service with Classic Load Balancer
apiVersion: v1
kind: Service
metadata:
  name: frontend-service
  namespace: online-boutique
  annotations:
    service.beta.kubernetes.io/aws-load-balancer-type: "classic"
    service.beta.kubernetes.io/aws-load-balancer-connection-idle-timeout: "4000"
    service.beta.kubernetes.io/aws-load-balancer-cross-zone-load-balancing-enabled: "true"
spec:
  type: LoadBalancer
  ports:
  - port: 80
    targetPort: 8080
    protocol: TCP
  selector:
    app: frontend
```

## ⚙️ **Configuration Options**

### **CLB Annotations**

```yaml
annotations:
  # Load Balancer Type
  service.beta.kubernetes.io/aws-load-balancer-type: "classic"
  
  # Connection Settings
  service.beta.kubernetes.io/aws-load-balancer-connection-idle-timeout: "4000"
  service.beta.kubernetes.io/aws-load-balancer-connection-draining-enabled: "true"
  service.beta.kubernetes.io/aws-load-balancer-connection-draining-timeout: "300"
  
  # Cross-Zone Load Balancing
  service.beta.kubernetes.io/aws-load-balancer-cross-zone-load-balancing-enabled: "true"
  
  # Security Groups
  service.beta.kubernetes.io/aws-load-balancer-additional-security-groups: "sg-12345678"
  
  # Subnets
  service.beta.kubernetes.io/aws-load-balancer-subnets: "subnet-12345678,subnet-87654321"
  
  # SSL Certificate (if using HTTPS)
  service.beta.kubernetes.io/aws-load-balancer-ssl-cert: "arn:aws:acm:region:account:certificate/certificate-id"
  service.beta.kubernetes.io/aws-load-balancer-ssl-ports: "443"
```

### **Health Check Configuration**

```yaml
annotations:
  # Health Check Path
  service.beta.kubernetes.io/aws-load-balancer-healthcheck-path: "/health"
  
  # Health Check Port
  service.beta.kubernetes.io/aws-load-balancer-healthcheck-port: "8080"
  
  # Health Check Protocol
  service.beta.kubernetes.io/aws-load-balancer-healthcheck-protocol: "HTTP"
  
  # Health Check Interval
  service.beta.kubernetes.io/aws-load-balancer-healthcheck-interval: "30"
  
  # Health Check Timeout
  service.beta.kubernetes.io/aws-load-balancer-healthcheck-timeout: "5"
  
  # Healthy Threshold
  service.beta.kubernetes.io/aws-load-balancer-healthcheck-healthy-threshold: "2"
  
  # Unhealthy Threshold
  service.beta.kubernetes.io/aws-load-balancer-healthcheck-unhealthy-threshold: "2"
```

## 📊 **Comparison: CLB vs NLB vs ALB**

| Feature | Classic Load Balancer (CLB) | Network Load Balancer (NLB) | Application Load Balancer (ALB) |
|---------|------------------------------|------------------------------|----------------------------------|
| **Cost** | ✅ Lowest | ❌ Highest | ⚠️ Medium |
| **Performance** | ⚠️ Good | ✅ Best | ✅ Good |
| **Features** | ⚠️ Basic | ✅ Advanced | ✅ Advanced |
| **SSL Termination** | ✅ Yes | ❌ No | ✅ Yes |
| **Path-based Routing** | ❌ No | ❌ No | ✅ Yes |
| **Host-based Routing** | ❌ No | ❌ No | ✅ Yes |
| **WebSocket Support** | ✅ Yes | ✅ Yes | ✅ Yes |
| **IPv6 Support** | ❌ No | ✅ Yes | ✅ Yes |
| **Target Groups** | ❌ No | ✅ Yes | ✅ Yes |
| **AWS Load Balancer Controller** | ❌ Not Required | ✅ Required | ✅ Required |

## 🛠️ **Implementation Examples**

### **1. Observability Services with CLB**

```bash
# Deploy observability framework with Classic Load Balancers
./installation/deploy-aws-observability.sh \
  --load-balancer-type clb \
  --cluster-name my-cluster \
  --region us-east-1
```

### **2. Online Boutique with CLB**

```bash
# Deploy online boutique with Classic Load Balancers
./installation/deploy-online-boutique.sh \
  --load-balancer-type clb \
  --external-access
```

### **3. Custom Service with CLB**

```yaml
apiVersion: v1
kind: Service
metadata:
  name: my-app-service
  namespace: my-namespace
  annotations:
    service.beta.kubernetes.io/aws-load-balancer-type: "classic"
    service.beta.kubernetes.io/aws-load-balancer-cross-zone-load-balancing-enabled: "true"
    service.beta.kubernetes.io/aws-load-balancer-connection-idle-timeout: "4000"
    service.beta.kubernetes.io/aws-load-balancer-healthcheck-path: "/health"
    service.beta.kubernetes.io/aws-load-balancer-healthcheck-port: "8080"
spec:
  type: LoadBalancer
  ports:
  - name: http
    port: 80
    targetPort: 8080
    protocol: TCP
  - name: https
    port: 443
    targetPort: 8443
    protocol: TCP
  selector:
    app: my-app
```

## 🔧 **Troubleshooting**

### **Common Issues**

1. **Load Balancer Not Created**
   ```bash
   # Check if AWS Load Balancer Controller is required
   kubectl get pods -n kube-system | grep aws-load-balancer-controller
   
   # For CLB, controller is not required
   # Check service status
   kubectl get svc -n your-namespace
   ```

2. **Health Check Failures**
   ```bash
   # Check if health check endpoint exists
   kubectl exec -it <pod-name> -- curl -f /health
   
   # Verify health check configuration
   kubectl describe svc <service-name>
   ```

3. **Connection Timeouts**
   ```bash
   # Check connection idle timeout
   kubectl get svc <service-name> -o yaml | grep idle-timeout
   
   # Increase timeout if needed
   kubectl patch svc <service-name> -p '{"metadata":{"annotations":{"service.beta.kubernetes.io/aws-load-balancer-connection-idle-timeout":"6000"}}}'
   ```

### **Monitoring CLB**

```bash
# Check Load Balancer status
kubectl get svc -o wide

# Get Load Balancer DNS name
kubectl get svc <service-name> -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'

# Test connectivity
curl -I http://<load-balancer-dns-name>
```

## 💰 **Cost Optimization**

### **CLB Cost Benefits**
- **No AWS Load Balancer Controller**: Saves on controller costs
- **Lower Data Processing**: CLB has lower data processing costs
- **Simpler Architecture**: Fewer components to manage

### **Cost Comparison (Approximate)**
- **CLB**: $0.025/hour + $0.008/GB
- **NLB**: $0.0225/hour + $0.006/GB
- **ALB**: $0.0225/hour + $0.008/GB

*Note: Actual costs may vary by region and usage*

## 🎯 **Best Practices**

### **1. Security**
- Use security groups to restrict access
- Enable SSL termination for HTTPS traffic
- Implement proper health checks

### **2. Performance**
- Enable cross-zone load balancing
- Configure appropriate connection timeouts
- Monitor and adjust health check settings

### **3. Reliability**
- Use multiple availability zones
- Implement proper health check endpoints
- Monitor Load Balancer metrics

### **4. Cost Management**
- Clean up unused Load Balancers
- Monitor data transfer costs
- Use appropriate instance types

## 🚀 **Quick Start**

```bash
# 1. Deploy with Classic Load Balancers
./installation/deploy-aws-observability.sh --load-balancer-type clb

# 2. Deploy application
./installation/deploy-online-boutique.sh --load-balancer-type clb

# 3. Get access URLs
kubectl get svc -n monitoring
kubectl get svc -n online-boutique

# 4. Test connectivity
curl -I http://<load-balancer-dns-name>
```

Classic Load Balancers provide a simple, cost-effective solution for most use cases while maintaining good performance and reliability. 