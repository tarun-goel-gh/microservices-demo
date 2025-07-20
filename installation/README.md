# Installation Guide for Microservices Demo

This directory contains all the installation and deployment artifacts for the microservices-demo application on AWS EKS.

## Quick Start

### Prerequisites
- AWS CLI configured with appropriate permissions
- kubectl installed
- eksctl installed (will be installed automatically if missing)
- Docker (for local development)

### One-Command Deployment
```bash
./installation/deploy-to-aws-eks.sh
```

This script will:
1. Check for existing EKS clusters or create a new one
2. Deploy the microservices application
3. Optionally deploy the monitoring stack
4. Provide access URLs and useful commands

## Installation Components

### Core Installation Scripts

#### `deploy-to-aws-eks.sh`
- **Purpose**: Main deployment script for the entire application
- **Features**:
  - EKS cluster creation/configuration
  - AWS Load Balancer Controller setup
  - Application deployment (Helm or manifests)
  - Monitoring stack deployment option
  - AWS-specific optimizations

#### `deploy-monitoring.sh`
- **Purpose**: Deploy the complete observability stack
- **Components**:
  - Prometheus (metrics collection)
  - Mimir (scalable metrics storage)
  - Loki (log aggregation)
  - Tempo (distributed tracing)
  - OpenTelemetry Collector
  - Grafana (visualization)
  - kube-state-metrics
  - node-exporter
  - Promtail (log collection)

#### `cleanup-monitoring.sh`
- **Purpose**: Remove the monitoring stack
- **Features**:
  - Safe cleanup with confirmation
  - Removes all monitoring components
  - Cleans up cluster roles and bindings
  - Removes persistent volumes

#### `undeploy-from-aws-eks.sh`
- **Purpose**: Complete application cleanup
- **Features**:
  - Removes all application components
  - Optionally deletes the EKS cluster
  - Cleans up AWS resources

### Cluster Management Scripts

#### `add-user-to-cluster.sh`
- **Purpose**: Add IAM users to the EKS cluster
- **Features**:
  - Configures kubectl for additional users
  - Sets up RBAC permissions
  - Manages cluster access

#### `fix-cluster-permissions.sh`
- **Purpose**: Fix common EKS permission issues
- **Features**:
  - Resolves RBAC configuration problems
  - Fixes service account issues
  - Configures proper cluster access

#### `setup-prerequisites.sh`
- **Purpose**: Install required tools
- **Features**:
  - Installs kubectl, helm, eksctl
  - Configures AWS CLI
  - Sets up development environment

### Configuration Files

#### `aws-optimized-manifests.yaml`
- **Purpose**: AWS-specific optimizations for the application
- **Features**:
  - Load balancer configurations
  - Resource optimizations
  - AWS-specific annotations

### Documentation

#### `AWS-EKS-SETUP.md`
- **Purpose**: Detailed AWS EKS setup guide
- **Contents**:
  - Step-by-step cluster creation
  - Configuration details
  - Troubleshooting tips

#### `CLEANUP-GUIDE.md`
- **Purpose**: Complete cleanup instructions
- **Contents**:
  - Resource cleanup procedures
  - Cost optimization tips
  - Verification steps

#### `TROUBLESHOOTING.md`
- **Purpose**: Common issues and solutions
- **Contents**:
  - Installation problems
  - Runtime issues
  - Debugging procedures

### Credentials and Keys

#### `ai_user_credentials.csv`
- **Purpose**: Sample user credentials for testing
- **Note**: Replace with your own credentials in production

#### `keys`
- **Purpose**: SSH keys for cluster access
- **Note**: Secure these files appropriately

## Deployment Options

### 1. Complete Deployment (Recommended)
```bash
./installation/deploy-to-aws-eks.sh
```
- Deploys everything in one command
- Includes monitoring stack option
- Best for new deployments

### 2. Application Only
```bash
./installation/deploy-to-aws-eks.sh
# Choose option 2 when prompted for monitoring
```
- Deploys only the microservices application
- Skips monitoring stack
- Faster deployment

### 3. Monitoring Only
```bash
./installation/deploy-monitoring.sh
```
- Deploys only the observability stack
- Requires existing application deployment
- Useful for adding monitoring later

### 4. Manual Step-by-Step
```bash
# 1. Setup prerequisites
./installation/setup-prerequisites.sh

# 2. Create cluster (if needed)
eksctl create cluster --name ecommerce-01-cluster --region us-east-1

# 3. Deploy application
kubectl apply -f release/kubernetes-manifests.yaml

# 4. Deploy monitoring (optional)
./installation/deploy-monitoring.sh
```

## Configuration

### Environment Variables
The scripts use the following default values:
- `NAMESPACE`: `ecomm-prod`
- `CLUSTER_NAME`: `ecommerce-01-cluster`
- `REGION`: `us-east-1`
- `DEPLOYMENT_METHOD`: `helm`

You can override these by setting environment variables:
```bash
export NAMESPACE="my-namespace"
export CLUSTER_NAME="my-cluster"
export REGION="us-west-2"
./installation/deploy-to-aws-eks.sh
```

### AWS Configuration
Ensure your AWS CLI is configured:
```bash
aws configure
# Enter your AWS Access Key ID
# Enter your AWS Secret Access Key
# Enter your default region
# Enter your output format (json)
```

## Access URLs

After deployment, you'll have access to:

### Application
- **Frontend**: `http://<loadbalancer-url>`
- **Internal Services**: Available within the cluster

### Monitoring (if deployed)
- **Grafana**: `http://<loadbalancer-url>:3000` (admin/admin)
- **Prometheus**: `http://prometheus.monitoring.svc.cluster.local:9090`
- **Loki**: `http://loki.monitoring.svc.cluster.local:3100`
- **Tempo**: `http://tempo.monitoring.svc.cluster.local:3200`

### Port Forwarding (for local access)
```bash
# Application
kubectl port-forward -n ecomm-prod svc/frontend-external 8080:8080

# Monitoring
kubectl port-forward -n monitoring svc/grafana 3000:3000
kubectl port-forward -n monitoring svc/prometheus 9090:9090
kubectl port-forward -n monitoring svc/loki 3100:3100
kubectl port-forward -n monitoring svc/tempo 3200:3200
```

## Useful Commands

### Check Deployment Status
```bash
# Application status
kubectl get pods -n ecomm-prod
kubectl get services -n ecomm-prod

# Monitoring status
kubectl get pods -n monitoring
kubectl get services -n monitoring
```

### View Logs
```bash
# Application logs
kubectl logs -f deployment/frontend -n ecomm-prod
kubectl logs -f deployment/cartservice -n ecomm-prod

# Monitoring logs
kubectl logs -f deployment/prometheus -n monitoring
kubectl logs -f deployment/grafana -n monitoring
```

### Scale Services
```bash
# Scale frontend
kubectl scale deployment frontend --replicas=3 -n ecomm-prod

# Scale monitoring components
kubectl scale deployment prometheus --replicas=2 -n monitoring
```

## Cleanup

### Remove Application Only
```bash
kubectl delete namespace ecomm-prod
```

### Remove Monitoring Only
```bash
./installation/cleanup-monitoring.sh
```

### Complete Cleanup
```bash
./installation/undeploy-from-aws-eks.sh
```

## Troubleshooting

### Common Issues

1. **Cluster Access Issues**
   ```bash
   ./installation/fix-cluster-permissions.sh
   ```

2. **Load Balancer Not Provisioning**
   ```bash
   kubectl get events -n ecomm-prod --sort-by='.lastTimestamp'
   ```

3. **Monitoring Components Not Starting**
   ```bash
   kubectl describe pod <pod-name> -n monitoring
   kubectl logs <pod-name> -n monitoring
   ```

4. **Storage Issues**
   ```bash
   kubectl get pvc -n monitoring
   kubectl describe pvc <pvc-name> -n monitoring
   ```

### Getting Help

1. Check the `TROUBLESHOOTING.md` file for common solutions
2. Review the logs of failing components
3. Verify AWS service quotas and limits
4. Check the AWS EKS console for cluster status

## Cost Optimization

### Resource Recommendations
- **Development**: Use smaller instance types (t3.medium)
- **Production**: Use larger instances (m6a.xlarge) for better performance
- **Monitoring**: Start with single replicas, scale as needed

### Cleanup Reminders
- Always clean up resources when done testing
- Monitor AWS costs in the billing console
- Use AWS Cost Explorer to track spending

## Security Considerations

### Production Deployment
- Change default passwords (Grafana admin/admin)
- Use AWS Secrets Manager for sensitive data
- Enable AWS CloudTrail for audit logging
- Configure proper RBAC permissions
- Use private subnets for database components
- Enable encryption at rest and in transit

### Network Security
- Configure security groups appropriately
- Use AWS WAF for web application protection
- Enable VPC flow logs for network monitoring
- Consider using AWS PrivateLink for internal services 