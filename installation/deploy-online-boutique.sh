#!/bin/bash

# Online Boutique Microservices Deployment Script
# This script deploys the complete online boutique application

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
NAMESPACE="production"
DEPLOYMENT_METHOD="kubernetes"  # Options: kubernetes, helm, kustomize
ENABLE_ISTIO="true"
ENABLE_LOAD_GENERATOR="false"
ENABLE_MONITORING="true"
EXTERNAL_ACCESS="true"
LOAD_BALANCER_TYPE="clb"  # Options: nlb, alb, clb (Classic Load Balancer)

# Function to check prerequisites
check_prerequisites() {
    print_info "Checking prerequisites..."
    
    # Check kubectl
    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl is not installed. Please install kubectl first."
        exit 1
    fi
    
    # Check cluster access
    if ! kubectl cluster-info &> /dev/null; then
        print_error "Cannot connect to Kubernetes cluster. Please check your kubeconfig."
        exit 1
    fi
    
    # Check cluster resources
    print_info "Checking cluster resources..."
    kubectl get nodes
    
    # Check if namespace exists
    if kubectl get namespace $NAMESPACE &> /dev/null; then
        print_warning "Namespace $NAMESPACE already exists. Consider using a different namespace or cleaning up first."
        read -p "Continue with existing namespace? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_info "Deployment cancelled."
            exit 0
        fi
    fi
    
    print_success "Prerequisites check passed!"
}

# Function to create namespace and RBAC
setup_namespace_and_rbac() {
    print_info "Setting up namespace and RBAC..."
    
    # Create namespace
    kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -
    
    # Create service account
    cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  name: online-boutique-sa
  namespace: $NAMESPACE
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: online-boutique-role
  namespace: $NAMESPACE
rules:
- apiGroups: [""]
  resources: ["pods", "services", "endpoints"]
  verbs: ["get", "list", "watch"]
- apiGroups: ["apps"]
  resources: ["deployments", "replicasets"]
  verbs: ["get", "list", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: online-boutique-rolebinding
  namespace: $NAMESPACE
subjects:
- kind: ServiceAccount
  name: online-boutique-sa
  namespace: $NAMESPACE
roleRef:
  kind: Role
  name: online-boutique-role
  apiGroup: rbac.authorization.k8s.io
EOF
    
    print_success "Namespace and RBAC setup completed!"
}

# Function to deploy microservices using Kubernetes manifests
deploy_with_kubernetes() {
    print_info "Deploying microservices using Kubernetes manifests..."
    
    # Deploy core services
    print_info "Deploying core services..."
    kubectl apply -f kubernetes-manifests/productcatalogservice.yaml -n $NAMESPACE
    kubectl apply -f kubernetes-manifests/cartservice.yaml -n $NAMESPACE
    kubectl apply -f kubernetes-manifests/currencyservice.yaml -n $NAMESPACE
    kubectl apply -f kubernetes-manifests/emailservice.yaml -n $NAMESPACE
    kubectl apply -f kubernetes-manifests/paymentservice.yaml -n $NAMESPACE
    kubectl apply -f kubernetes-manifests/shippingservice.yaml -n $NAMESPACE
    kubectl apply -f kubernetes-manifests/checkoutservice.yaml -n $NAMESPACE
    kubectl apply -f kubernetes-manifests/recommendationservice.yaml -n $NAMESPACE
    kubectl apply -f kubernetes-manifests/adservice.yaml -n $NAMESPACE
    
    # Deploy frontend
    print_info "Deploying frontend..."
    kubectl apply -f kubernetes-manifests/frontend.yaml -n $NAMESPACE
    
    # Deploy load generator if enabled
    if [ "$ENABLE_LOAD_GENERATOR" = "true" ]; then
        print_info "Deploying load generator..."
        kubectl apply -f kubernetes-manifests/loadgenerator.yaml -n $NAMESPACE
    fi
    
    print_success "Kubernetes manifests deployment completed!"
}

# Function to deploy using Helm
deploy_with_helm() {
    print_info "Deploying microservices using Helm..."
    
    # Check if helm is installed
    if ! command -v helm &> /dev/null; then
        print_error "Helm is not installed. Please install Helm first."
        exit 1
    fi
    
    # Create values file for this deployment
    cat <<EOF > helm-values.yaml
namespace: $NAMESPACE
loadGenerator:
  enabled: $ENABLE_LOAD_GENERATOR
frontend:
  service:
    type: ClusterIP
EOF
    
    # Deploy using Helm
    helm install online-boutique ./helm-chart \
        --namespace $NAMESPACE \
        --create-namespace \
        --values helm-values.yaml
    
    print_success "Helm deployment completed!"
}

# Function to deploy using Kustomize
deploy_with_kustomize() {
    print_info "Deploying microservices using Kustomize..."
    
    # Check if kustomize is installed
    if ! command -v kustomize &> /dev/null; then
        print_error "Kustomize is not installed. Please install Kustomize first."
        exit 1
    fi
    
    # Deploy using Kustomize
    kubectl apply -k kustomize/base/ -n $NAMESPACE
    
    print_success "Kustomize deployment completed!"
}

# Function to deploy Istio (optional)
deploy_istio() {
    if [ "$ENABLE_ISTIO" = "true" ]; then
        print_info "Deploying Istio service mesh..."
        
        # Check if Istio is installed
        if ! command -v istioctl &> /dev/null; then
            print_warning "Istio CLI not found. Skipping Istio deployment."
            return 0
        fi
        
        # Apply Istio manifests
        kubectl apply -f istio-manifests/frontend-gateway.yaml -n $NAMESPACE
        kubectl apply -f istio-manifests/frontend.yaml -n $NAMESPACE
        
        print_success "Istio deployment completed!"
    fi
}

# Function to configure external access
configure_external_access() {
    if [ "$EXTERNAL_ACCESS" = "true" ]; then
        print_info "Configuring external access..."
        
        # Patch frontend service to LoadBalancer
        kubectl patch svc frontend -n $NAMESPACE -p '{"spec":{"type":"LoadBalancer"}}'
        
        # Wait for Load Balancer
        print_info "Waiting for Load Balancer to be provisioned..."
        kubectl wait --for=condition=Available=True --timeout=300s deployment/frontend -n $NAMESPACE
        
        print_success "External access configured!"
    fi
}

# Function to wait for deployments
wait_for_deployments() {
    print_info "Waiting for all deployments to be ready..."
    
    local deployments=(
        "productcatalogservice"
        "cartservice"
        "currencyservice"
        "emailservice"
        "paymentservice"
        "shippingservice"
        "checkoutservice"
        "recommendationservice"
        "adservice"
        "frontend"
    )
    
    if [ "$ENABLE_LOAD_GENERATOR" = "true" ]; then
        deployments+=("loadgenerator")
    fi
    
    for deployment in "${deployments[@]}"; do
        print_info "Waiting for $deployment deployment..."
        kubectl wait --for=condition=available --timeout=600s deployment/$deployment -n $NAMESPACE
        print_success "$deployment deployment is ready!"
    done
    
    print_success "All deployments are ready!"
}

# Function to verify deployment
verify_deployment() {
    print_info "Verifying deployment..."
    
    # Check all pods
    print_info "Checking pod status..."
    kubectl get pods -n $NAMESPACE
    
    # Check all services
    print_info "Checking service status..."
    kubectl get services -n $NAMESPACE
    
    # Test frontend connectivity
    print_info "Testing frontend connectivity..."
    
    # Get frontend service
    FRONTEND_SERVICE=$(kubectl get svc frontend -n $NAMESPACE -o jsonpath='{.metadata.name}')
    
    # Test internal connectivity
    if kubectl run test-frontend --image=curlimages/curl --rm -i --restart=Never -n $NAMESPACE -- curl -s http://$FRONTEND_SERVICE:8080/health &> /dev/null; then
        print_success "Frontend is accessible internally!"
    else
        print_warning "Frontend internal connectivity test failed"
    fi
    
    # Test external connectivity if LoadBalancer is configured
    if [ "$EXTERNAL_ACCESS" = "true" ]; then
        FRONTEND_LB=$(kubectl get svc frontend -n $NAMESPACE -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
        if [ ! -z "$FRONTEND_LB" ]; then
            print_info "Testing external connectivity to http://$FRONTEND_LB"
            if curl -s --max-time 10 "http://$FRONTEND_LB" &> /dev/null; then
                print_success "Frontend is accessible externally!"
            else
                print_warning "Frontend external connectivity test failed"
            fi
        fi
    fi
    
    print_success "Deployment verification completed!"
}

# Function to display access information
display_access_info() {
    echo ""
    echo "=========================================="
    echo "🛍️  ONLINE BOUTIQUE DEPLOYED!"
    echo "=========================================="
    echo ""
    echo "Namespace: $NAMESPACE"
    echo "Deployment Method: $DEPLOYMENT_METHOD"
    echo "Istio Enabled: $ENABLE_ISTIO"
    echo "Load Generator: $ENABLE_LOAD_GENERATOR"
    echo ""
    
    # Get service information
    echo "Services:"
    echo "---------"
    kubectl get svc -n $NAMESPACE
    
    echo ""
    echo "Access URLs:"
    echo "------------"
    
    if [ "$EXTERNAL_ACCESS" = "true" ]; then
        FRONTEND_LB=$(kubectl get svc frontend -n $NAMESPACE -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
        if [ ! -z "$FRONTEND_LB" ]; then
            echo "🌐 Frontend (External): http://$FRONTEND_LB"
        else
            echo "🌐 Frontend (External): Load Balancer still provisioning..."
        fi
    fi
    
    echo "🔗 Frontend (Internal): http://frontend.$NAMESPACE.svc.cluster.local:8080"
    echo "🔗 Frontend (Port Forward): kubectl port-forward -n $NAMESPACE svc/frontend 8080:8080"
    echo ""
    
    echo "Service Endpoints:"
    echo "------------------"
    echo "📦 Product Catalog: http://productcatalogservice.$NAMESPACE.svc.cluster.local:3550"
    echo "🛒 Cart Service: http://cartservice.$NAMESPACE.svc.cluster.local:7070"
    echo "💳 Payment Service: http://paymentservice.$NAMESPACE.svc.cluster.local:50051"
    echo "📧 Email Service: http://emailservice.$NAMESPACE.svc.cluster.local:8080"
    echo "🚚 Shipping Service: http://shippingservice.$NAMESPACE.svc.cluster.local:50051"
    echo "💱 Currency Service: http://currencyservice.$NAMESPACE.svc.cluster.local:7000"
    echo "🔍 Recommendation Service: http://recommendationservice.$NAMESPACE.svc.cluster.local:8080"
    echo "📢 Ad Service: http://adservice.$NAMESPACE.svc.cluster.local:9555"
    echo ""
    
    echo "Next Steps:"
    echo "-----------"
    echo "1. Access the frontend application"
    echo "2. Monitor the application using the observability framework"
    echo "3. Test the load generator (if enabled)"
    echo "4. Configure custom domains and SSL (for production)"
    echo ""
    
    echo "Useful Commands:"
    echo "----------------"
    echo "kubectl get pods -n $NAMESPACE"
    echo "kubectl logs -f deployment/frontend -n $NAMESPACE"
    echo "kubectl describe svc frontend -n $NAMESPACE"
    echo "kubectl port-forward -n $NAMESPACE svc/frontend 8080:8080"
    echo ""
}

# Function to show monitoring integration
show_monitoring_integration() {
    if [ "$ENABLE_MONITORING" = "true" ]; then
        echo ""
        print_info "Monitoring Integration"
        echo "========================"
        echo ""
        echo "The online boutique is now ready for monitoring integration."
        echo ""
        echo "To integrate with the observability framework:"
        echo "1. Deploy the observability framework: ./installation/deploy-aws-observability.sh"
        echo "2. Configure service discovery for the microservices"
        echo "3. Set up custom dashboards for the online boutique"
        echo "4. Configure alerts for application metrics"
        echo ""
        echo "Key metrics to monitor:"
        echo "- Request latency and throughput"
        echo "- Error rates and availability"
        echo "- Resource usage (CPU, memory)"
        echo "- Business metrics (orders, revenue)"
        echo ""
    fi
}

# Function to show troubleshooting tips
show_troubleshooting_tips() {
    echo ""
    print_info "Troubleshooting Tips"
    echo "======================"
    echo ""
    echo "If you encounter issues:"
    echo ""
    echo "1. Check pod status:"
    echo "   kubectl get pods -n $NAMESPACE"
    echo ""
    echo "2. Check pod logs:"
    echo "   kubectl logs -f deployment/frontend -n $NAMESPACE"
    echo ""
    echo "3. Check service endpoints:"
    echo "   kubectl get endpoints -n $NAMESPACE"
    echo ""
    echo "4. Check resource usage:"
    echo "   kubectl top pods -n $NAMESPACE"
    echo ""
    echo "5. Check events:"
    echo "   kubectl get events -n $NAMESPACE --sort-by='.lastTimestamp'"
    echo ""
    echo "6. Restart a deployment:"
    echo "   kubectl rollout restart deployment/frontend -n $NAMESPACE"
    echo ""
}

# Function to parse command line arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --namespace)
                NAMESPACE="$2"
                shift 2
                ;;
            --method)
                DEPLOYMENT_METHOD="$2"
                shift 2
                ;;
            --enable-istio)
                ENABLE_ISTIO="true"
                shift
                ;;
            --disable-load-generator)
                ENABLE_LOAD_GENERATOR="false"
                shift
                ;;
            --disable-monitoring)
                ENABLE_MONITORING="false"
                shift
                ;;
            --external-access)
                EXTERNAL_ACCESS="true"
                shift
                ;;
            --help)
                show_help
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
}

# Function to show help
show_help() {
    echo "Online Boutique Microservices Deployment Script"
    echo "=============================================="
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --namespace NAME           Namespace to deploy to (default: online-boutique)"
    echo "  --method METHOD            Deployment method: kubernetes, helm, kustomize (default: kubernetes)"
    echo "  --enable-istio             Enable Istio service mesh"
    echo "  --disable-load-generator   Disable load generator deployment"
    echo "  --disable-monitoring       Disable monitoring integration hints"
    echo "  --external-access          Configure external access via LoadBalancer"
    echo "  --help                     Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                                    # Deploy with default settings"
    echo "  $0 --namespace boutique --external-access  # Deploy with external access"
    echo "  $0 --method helm --enable-istio       # Deploy using Helm with Istio"
    echo ""
}

# Main function
main() {
    echo "🛍️  Online Boutique Microservices Deployment"
    echo "============================================"
    echo ""
    echo "This script will deploy the complete online boutique application."
    echo ""
    echo "Configuration:"
    echo "- Namespace: $NAMESPACE"
    echo "- Deployment Method: $DEPLOYMENT_METHOD"
    echo "- Istio Enabled: $ENABLE_ISTIO"
    echo "- Load Generator: $ENABLE_LOAD_GENERATOR"
    echo "- External Access: $EXTERNAL_ACCESS"
    echo ""
    
    # Parse command line arguments
    parse_arguments "$@"
    
    # Check prerequisites
    check_prerequisites
    
    # Setup namespace and RBAC
    setup_namespace_and_rbac
    
    # Deploy based on method
    case $DEPLOYMENT_METHOD in
        "kubernetes")
            deploy_with_kubernetes
            ;;
        "helm")
            deploy_with_helm
            ;;
        "kustomize")
            deploy_with_kustomize
            ;;
        *)
            print_error "Unknown deployment method: $DEPLOYMENT_METHOD"
            exit 1
            ;;
    esac
    
    # Deploy Istio if enabled
    deploy_istio
    
    # Configure external access
    configure_external_access
    
    # Wait for deployments
    wait_for_deployments
    
    # Verify deployment
    verify_deployment
    
    # Display access information
    display_access_info
    
    # Show monitoring integration
    show_monitoring_integration
    
    # Show troubleshooting tips
    show_troubleshooting_tips
    
    print_success "🎉 Online Boutique deployment completed successfully!"
    print_info "Access your application at the URLs shown above."
}

# Run main function
main "$@" 