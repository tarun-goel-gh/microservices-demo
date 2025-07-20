#!/bin/bash

# AWS Observability Framework Deployment Script
# This script deploys AWS resources and the complete observability framework

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Configuration variables
CLUSTER_NAME="ecom-prod-cluster"
REGION="us-east-1"
NODE_TYPE="t3a.xlarge"
NODE_COUNT=5
VPC_CIDR="10.0.0.0/16"
SUBNET_CIDR="10.0.1.0/24"
EKS_VERSION="1.33"
CLUSTER_ROLE_NAME="eks-cluster-role"
NODE_ROLE_NAME="eks-node-role"

# Function to check prerequisites
check_prerequisites() {
    print_info "Checking prerequisites..."
    
    # Check AWS CLI
    if ! command -v aws &> /dev/null; then
        print_error "AWS CLI is not installed. Please install AWS CLI first."
        exit 1
    fi
    
    # Check kubectl
    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl is not installed. Please install kubectl first."
        exit 1
    fi
    
    # Check eksctl
    if ! command -v eksctl &> /dev/null; then
        print_error "eksctl is not installed. Please install eksctl first."
        exit 1
    fi
    
    # Check AWS credentials
    if ! aws sts get-caller-identity &> /dev/null; then
        print_error "AWS credentials not configured. Please run 'aws configure' first."
        exit 1
    fi
    
    # Check AWS region
    aws configure get region || {
        print_warning "AWS region not set. Setting to $REGION"
        aws configure set region $REGION
    }
    
    print_success "Prerequisites check passed!"
}

# Function to create AWS resources
deploy_aws_resources() {
    print_info "Phase 1: Deploying AWS Resources"
    echo "====================================="
    
    # Create EKS cluster
    print_info "Creating EKS cluster: $CLUSTER_NAME"
    
    eksctl create cluster \
        --name $CLUSTER_NAME \
        --region $REGION \
        --nodegroup-name standard-workers \
        --node-type $NODE_TYPE \
        --nodes $NODE_COUNT \
        --nodes-min 2 \
        --nodes-max 10 \
        --managed \
        --version $EKS_VERSION \
        --with-oidc \
        --ssh-access \
        --ssh-public-key installation/id_rsa_eks.pub \
        --full-ecr-access \
        --appmesh-access \
        --alb-ingress-access \
        --auto-kubeconfig
    
    # Wait for cluster to be ready
    print_info "Waiting for cluster to be ready..."
    
    # Try eksctl utils wait first (if available)
    if eksctl utils wait --help &> /dev/null; then
        print_info "Using eksctl utils wait command..."
        if eksctl utils wait --cluster $CLUSTER_NAME --region $REGION; then
            print_success "Cluster is ready (using eksctl utils wait)!"
        else
            print_warning "eksctl utils wait failed, falling back to manual wait..."
        fi
    else
        print_info "eksctl utils wait not available, using manual wait..."
    fi
    
    # Manual wait for EKS cluster to be active
    print_info "Waiting for EKS cluster to be active..."
    CLUSTER_TIMEOUT=1800  # 30 minutes
    CLUSTER_ELAPSED=0
    while [ $CLUSTER_ELAPSED -lt $CLUSTER_TIMEOUT ]; do
        CLUSTER_STATUS=$(aws eks describe-cluster --name $CLUSTER_NAME --region $REGION --query 'cluster.status' --output text 2>/dev/null || echo "NOT_FOUND")
        if [ "$CLUSTER_STATUS" = "ACTIVE" ]; then
            print_success "EKS cluster is active!"
            break
        elif [ "$CLUSTER_STATUS" = "NOT_FOUND" ]; then
            print_warning "Cluster not found yet, waiting... (${CLUSTER_ELAPSED}s elapsed)"
            sleep 30
            CLUSTER_ELAPSED=$((CLUSTER_ELAPSED + 30))
        else
            print_info "Cluster status: $CLUSTER_STATUS, waiting... (${CLUSTER_ELAPSED}s elapsed)"
            sleep 30
            CLUSTER_ELAPSED=$((CLUSTER_ELAPSED + 30))
        fi
    done
    
    if [ $CLUSTER_ELAPSED -ge $CLUSTER_TIMEOUT ]; then
        print_error "Timeout waiting for EKS cluster to be active after ${CLUSTER_TIMEOUT}s"
        exit 1
    fi
    
    # Manual wait for node groups to be ready
    print_info "Waiting for node groups to be ready..."
    NODE_TIMEOUT=1200  # 20 minutes
    NODE_ELAPSED=0
    while [ $NODE_ELAPSED -lt $NODE_TIMEOUT ]; do
        NODE_STATUS=$(aws eks describe-nodegroup --cluster-name $CLUSTER_NAME --nodegroup-name standard-workers --region $REGION --query 'nodegroup.status' --output text 2>/dev/null || echo "NOT_FOUND")
        if [ "$NODE_STATUS" = "ACTIVE" ]; then
            print_success "Node group is active!"
            break
        elif [ "$NODE_STATUS" = "NOT_FOUND" ]; then
            print_warning "Node group not found yet, waiting... (${NODE_ELAPSED}s elapsed)"
            sleep 30
            NODE_ELAPSED=$((NODE_ELAPSED + 30))
        else
            print_info "Node group status: $NODE_STATUS, waiting... (${NODE_ELAPSED}s elapsed)"
            sleep 30
            NODE_ELAPSED=$((NODE_ELAPSED + 30))
        fi
    done
    
    if [ $NODE_ELAPSED -ge $NODE_TIMEOUT ]; then
        print_error "Timeout waiting for node group to be active after ${NODE_TIMEOUT}s"
        exit 1
    fi
    
    # Update kubeconfig
    aws eks update-kubeconfig --name $CLUSTER_NAME --region $REGION
    
    # Verify kubectl connectivity
    print_info "Verifying kubectl connectivity..."
    KUBECTL_TIMEOUT=300  # 5 minutes
    KUBECTL_ELAPSED=0
    while [ $KUBECTL_ELAPSED -lt $KUBECTL_TIMEOUT ]; do
        if kubectl cluster-info &> /dev/null; then
            print_success "kubectl connectivity verified!"
            break
        else
            print_warning "kubectl not ready yet, waiting... (${KUBECTL_ELAPSED}s elapsed)"
            sleep 10
            KUBECTL_ELAPSED=$((KUBECTL_ELAPSED + 10))
        fi
    done
    
    if [ $KUBECTL_ELAPSED -ge $KUBECTL_TIMEOUT ]; then
        print_error "Timeout waiting for kubectl connectivity after ${KUBECTL_TIMEOUT}s"
        print_info "Trying to update kubeconfig again..."
        aws eks update-kubeconfig --name $CLUSTER_NAME --region $REGION
        if ! kubectl cluster-info &> /dev/null; then
            print_error "Failed to establish kubectl connectivity"
            exit 1
        fi
    fi
    
    # Create IAM OIDC provider
    print_info "Creating IAM OIDC provider..."
    eksctl utils associate-iam-oidc-provider --cluster $CLUSTER_NAME --region $REGION --approve
    
    # Create EBS CSI Driver IAM Role
    print_info "Creating EBS CSI Driver IAM Role..."
    eksctl create iamserviceaccount \
        --name ebs-csi-controller-sa \
        --namespace kube-system \
        --cluster $CLUSTER_NAME \
        --region $REGION \
        --attach-policy-arn arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy \
        --approve \
        --force-update
    
    # Install EBS CSI Driver
    print_info "Installing EBS CSI Driver..."
    kubectl apply -k "github.com/kubernetes-sigs/aws-ebs-csi-driver/deploy/kubernetes/overlays/stable/?ref=release-1.28"
    
    # Create storage classes
    print_info "Creating storage classes..."
    cat <<EOF | kubectl apply -f -
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: ebs-sc
provisioner: ebs.csi.aws.com
volumeBindingMode: WaitForFirstConsumer
parameters:
  type: gp3
  iops: "3000"
  throughput: "125"
---
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: ebs-sc-fast
provisioner: ebs.csi.aws.com
volumeBindingMode: WaitForFirstConsumer
parameters:
  type: io2
  iops: "10000"
EOF
    
    # Set default storage class
    kubectl patch storageclass ebs-sc -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
    
    # Install AWS Load Balancer Controller
    print_info "Installing AWS Load Balancer Controller..."
    eksctl create iamserviceaccount \
        --name aws-load-balancer-controller \
        --namespace kube-system \
        --cluster $CLUSTER_NAME \
        --region $REGION \
        --attach-policy-arn arn:aws:iam::aws:policy/AWSLoadBalancerControllerIAMPolicy \
        --approve \
        --force-update
    
    kubectl apply -k "github.com/kubernetes-sigs/aws-load-balancer-controller//deploy/eks/chart?ref=v2.7.1"
    
    # Install Prometheus Operator CRDs
    print_info "Installing Prometheus Operator CRDs..."
    kubectl apply -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/main/example/prometheus-operator-crd/monitoring.coreos.com_prometheusrules.yaml
    kubectl apply -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/main/example/prometheus-operator-crd/monitoring.coreos.com_servicemonitors.yaml
    kubectl apply -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/main/example/prometheus-operator-crd/monitoring.coreos.com_prometheuses.yaml
    
    print_success "AWS resources deployed successfully!"
}

# Function to deploy observability framework
deploy_observability_framework() {
    print_info "Phase 2: Deploying Observability Framework"
    echo "================================================"
    
    # Validate installation files
    print_info "Validating installation files..."
    local required_files=(
        "monitoring/namespace.yaml"
        "monitoring/prometheus-config.yaml"
        "monitoring/prometheus-deployment.yaml"
        "monitoring/enhanced-prometheus-rules-fixed.yaml"
        "monitoring/grafana-config.yaml"
        "monitoring/grafana-deployment.yaml"
        "monitoring/loki-config-enhanced.yaml"
        "monitoring/loki-deployment.yaml"
        "monitoring/vector-config-fixed.yaml"
        "monitoring/vector-deployment.yaml"
        "monitoring/tempo-config.yaml"
        "monitoring/tempo-deployment.yaml"
        "monitoring/alertmanager-config.yaml"
        "monitoring/alertmanager-deployment.yaml"
        "monitoring/alertmanager-templates.yaml"
    )
    
    for file in "${required_files[@]}"; do
        if [ ! -f "$file" ]; then
            print_error "Required file not found: $file"
            exit 1
        fi
    done
    
    print_success "All required files found!"
    
    # Create monitoring namespace
    print_info "Creating monitoring namespace..."
    kubectl apply -f monitoring/namespace.yaml
    
    # Deploy core monitoring components
    print_info "Deploying core monitoring components..."
    kubectl apply -f monitoring/prometheus-config.yaml
    kubectl apply -f monitoring/prometheus-deployment.yaml
    kubectl apply -f monitoring/enhanced-prometheus-rules-fixed.yaml
    
    kubectl apply -f monitoring/grafana-config.yaml
    kubectl apply -f monitoring/grafana-deployment.yaml
    kubectl apply -f monitoring/grafana-datasources.yaml
    kubectl apply -f monitoring/grafana-dashboards.yaml
    
    # Deploy logging stack
    print_info "Deploying logging stack..."
    kubectl apply -f monitoring/loki-config-enhanced.yaml
    kubectl apply -f monitoring/loki-deployment.yaml
    kubectl apply -f monitoring/vector-config-fixed.yaml
    kubectl apply -f monitoring/vector-deployment.yaml
    kubectl apply -f monitoring/promtail-config.yaml
    kubectl apply -f monitoring/promtail-daemonset.yaml
    
    # Deploy tracing stack
    print_info "Deploying tracing stack..."
    kubectl apply -f monitoring/tempo-config.yaml
    kubectl apply -f monitoring/tempo-deployment.yaml
    kubectl apply -f monitoring/otel-collector-config.yaml
    kubectl apply -f monitoring/otel-collector-deployment.yaml
    
    # Deploy alerting stack
    print_info "Deploying alerting stack..."
    kubectl apply -f monitoring/alertmanager-config.yaml
    kubectl apply -f monitoring/alertmanager-deployment.yaml
    kubectl apply -f monitoring/alertmanager-templates.yaml
    
    # Deploy additional components
    print_info "Deploying additional components..."
    kubectl apply -f monitoring/node-exporter.yaml
    kubectl apply -f monitoring/kube-state-metrics.yaml
    kubectl apply -f monitoring/mimir-config.yaml
    kubectl apply -f monitoring/mimir-deployment.yaml
    
    # Create AWS Load Balancer services for external access
    print_info "Creating Load Balancer services for external access..."
    kubectl patch svc grafana-service -n monitoring -p '{"spec":{"type":"LoadBalancer"}}'
    kubectl patch svc prometheus-service -n monitoring -p '{"spec":{"type":"LoadBalancer"}}'
    kubectl patch svc alertmanager-service -n monitoring -p '{"spec":{"type":"LoadBalancer"}}'
    
    print_success "Observability framework deployed successfully!"
}

# Function to wait for deployments
wait_for_deployments() {
    print_info "Waiting for all deployments to be ready..."
    
    local deployments=(
        "prometheus"
        "grafana"
        "loki"
        "vector"
        "tempo"
        "alertmanager"
        "mimir"
    )
    
    for deployment in "${deployments[@]}"; do
        print_info "Waiting for $deployment deployment..."
        kubectl wait --for=condition=available --timeout=600s deployment/$deployment -n monitoring
        print_success "$deployment deployment is ready!"
    done
    
    # Wait for Load Balancers to be provisioned
    print_info "Waiting for Load Balancers to be provisioned..."
    kubectl wait --for=condition=Ready --timeout=300s svc/grafana-service -n monitoring
    kubectl wait --for=condition=Ready --timeout=300s svc/prometheus-service -n monitoring
    kubectl wait --for=condition=Ready --timeout=300s svc/alertmanager-service -n monitoring
}

# Function to verify installation
verify_installation() {
    print_info "Phase 3: Verifying Installation"
    echo "===================================="
    
    # Check all pods
    print_info "Checking pod status..."
    kubectl get pods -n monitoring
    
    # Check all services
    print_info "Checking service status..."
    kubectl get services -n monitoring
    
    # Check Load Balancer endpoints
    print_info "Checking Load Balancer endpoints..."
    kubectl get svc -n monitoring -o wide
    
    # Test component health
    print_info "Testing component health..."
    
    # Get Load Balancer URLs
    GRAFANA_LB=$(kubectl get svc grafana-service -n monitoring -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
    PROMETHEUS_LB=$(kubectl get svc prometheus-service -n monitoring -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
    ALERTMANAGER_LB=$(kubectl get svc alertmanager-service -n monitoring -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
    
    # Test Prometheus
    if [ ! -z "$PROMETHEUS_LB" ]; then
        print_info "Testing Prometheus at http://$PROMETHEUS_LB"
        if curl -s --max-time 10 "http://$PROMETHEUS_LB/api/v1/status/config" &> /dev/null; then
            print_success "Prometheus is healthy!"
        else
            print_warning "Prometheus health check failed"
        fi
    fi
    
    # Test Grafana
    if [ ! -z "$GRAFANA_LB" ]; then
        print_info "Testing Grafana at http://$GRAFANA_LB"
        if curl -s --max-time 10 "http://$GRAFANA_LB/api/health" &> /dev/null; then
            print_success "Grafana is healthy!"
        else
            print_warning "Grafana health check failed"
        fi
    fi
    
    # Test Alertmanager
    if [ ! -z "$ALERTMANAGER_LB" ]; then
        print_info "Testing Alertmanager at http://$ALERTMANAGER_LB"
        if curl -s --max-time 10 "http://$ALERTMANAGER_LB/-/healthy" &> /dev/null; then
            print_success "Alertmanager is healthy!"
        else
            print_warning "Alertmanager health check failed"
        fi
    fi
    
    # Check resource usage
    print_info "Checking resource usage..."
    kubectl top pods -n monitoring
    
    # Check storage
    print_info "Checking storage..."
    kubectl get pvc -n monitoring
    
    print_success "Installation verification completed!"
}

# Function to display access information
display_access_info() {
    echo ""
    echo "=========================================="
    echo "🚀 AWS OBSERVABILITY FRAMEWORK DEPLOYED!"
    echo "=========================================="
    echo ""
    echo "Cluster Information:"
    echo "-------------------"
    echo "Cluster Name: $CLUSTER_NAME"
    echo "Region: $REGION"
    echo "EKS Version: $EKS_VERSION"
    echo ""
    
    # Get Load Balancer URLs
    GRAFANA_LB=$(kubectl get svc grafana-service -n monitoring -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
    PROMETHEUS_LB=$(kubectl get svc prometheus-service -n monitoring -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
    ALERTMANAGER_LB=$(kubectl get svc alertmanager-service -n monitoring -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
    
    echo "Access URLs:"
    echo "------------"
    if [ ! -z "$GRAFANA_LB" ]; then
        echo "📊 Grafana Dashboard: http://$GRAFANA_LB (admin/admin)"
    else
        echo "📊 Grafana Dashboard: Load Balancer still provisioning..."
    fi
    
    if [ ! -z "$PROMETHEUS_LB" ]; then
        echo "📈 Prometheus: http://$PROMETHEUS_LB"
    else
        echo "📈 Prometheus: Load Balancer still provisioning..."
    fi
    
    if [ ! -z "$ALERTMANAGER_LB" ]; then
        echo "🚨 Alertmanager: http://$ALERTMANAGER_LB"
    else
        echo "🚨 Alertmanager: Load Balancer still provisioning..."
    fi
    
    echo ""
    echo "Local Access (if Load Balancers not ready):"
    echo "-------------------------------------------"
    echo "kubectl port-forward -n monitoring svc/grafana-service 3000:3000"
    echo "kubectl port-forward -n monitoring svc/prometheus-service 9090:9090"
    echo "kubectl port-forward -n monitoring svc/alertmanager-service 9093:9093"
    echo ""
    
    echo "Next Steps:"
    echo "-----------"
    echo "1. Update Alertmanager config with your webhook URLs"
    echo "2. Configure your applications to expose metrics"
    echo "3. Set up custom dashboards for your services"
    echo "4. Configure alert channels for production use"
    echo "5. Set up monitoring for the monitoring stack itself"
    echo ""
    
    echo "Documentation:"
    echo "--------------"
    echo "- INSTALLATION_GUIDE.md - Complete installation guide"
    echo "- monitoring/OBSERVABILITY_FRAMEWORK.md - Architecture docs"
    echo "- installation/TROUBLESHOOTING.md - Troubleshooting guide"
    echo ""
}

# Function to show configuration notes
show_configuration_notes() {
    echo ""
    print_warning "IMPORTANT: Configuration Updates Required"
    echo "=================================================="
    echo ""
    echo "Before using in production, update these configurations:"
    echo ""
    echo "1. Alertmanager Configuration:"
    echo "   kubectl edit configmap alertmanager-config -n monitoring"
    echo "   - Replace YOUR_SLACK_WEBHOOK with actual Slack webhook URL"
    echo "   - Replace YOUR_PAGERDUTY_KEY with actual PagerDuty routing key"
    echo "   - Replace YOUR_EMAIL with actual email address"
    echo ""
    echo "2. Application Integration:"
    echo "   - Copy src/frontend/metrics.go to your applications"
    echo "   - Expose /metrics endpoints in your services"
    echo "   - Configure service discovery for your applications"
    echo ""
    echo "3. Security Hardening:"
    echo "   - Configure network policies"
    echo "   - Set up RBAC for applications"
    echo "   - Configure secrets management"
    echo ""
}

# Function to show cost optimization tips
show_cost_optimization() {
    echo ""
    print_info "Cost Optimization Tips"
    echo "=========================="
    echo ""
    echo "1. Node Groups:"
    echo "   - Use Spot instances for cost savings"
    echo "   - Right-size node groups based on workload"
    echo "   - Enable cluster autoscaler"
    echo ""
    echo "2. Storage:"
    echo "   - Use gp3 volumes for better cost/performance"
    echo "   - Implement data retention policies"
    echo "   - Monitor storage usage"
    echo ""
    echo "3. Load Balancers:"
    echo "   - Consider using ALB instead of NLB for cost savings"
    echo "   - Implement proper health checks"
    echo "   - Monitor Load Balancer costs"
    echo ""
}

# Function to cleanup on failure
cleanup_on_failure() {
    print_error "Deployment failed. Cleaning up..."
    
    # Delete EKS cluster
    print_info "Deleting EKS cluster..."
    eksctl delete cluster --name $CLUSTER_NAME --region $REGION --force
    
    print_error "Cleanup completed. Please check the logs and try again."
    exit 1
}

# Main function
main() {
    echo "🚀 AWS Observability Framework Deployment"
    echo "========================================="
    echo ""
    echo "This script will:"
    echo "1. Deploy AWS resources (EKS cluster, IAM roles, etc.)"
    echo "2. Deploy the complete observability framework"
    echo "3. Verify the installation"
    echo ""
    
    # Set trap for cleanup on failure
    trap cleanup_on_failure ERR
    
    # Check prerequisites
    check_prerequisites
    
    # Deploy AWS resources
    deploy_aws_resources
    
    # Deploy observability framework
    deploy_observability_framework
    
    # Wait for deployments
    wait_for_deployments
    
    # Verify installation
    verify_installation
    
    # Display access information
    display_access_info
    
    # Show configuration notes
    show_configuration_notes
    
    # Show cost optimization tips
    show_cost_optimization
    
    print_success "🎉 AWS Observability Framework deployment completed successfully!"
    print_info "Run './installation/validate-observability.sh' to perform a full validation."
}

# Run main function
main "$@" 