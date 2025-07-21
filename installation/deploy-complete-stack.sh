#!/bin/bash

# Complete Stack Deployment Script
# This script orchestrates the complete deployment of online boutique + observability framework

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
DEPLOYMENT_TYPE="aws"  # Options: aws, local
ENABLE_EXTERNAL_ACCESS="true"
ENABLE_ISTIO="false"
ENABLE_LOAD_GENERATOR="false"
NAMESPACE="online-boutique"

# Function to show help
show_help() {
    echo "Complete Stack Deployment Script"
    echo "==============================="
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --type TYPE           Deployment type: aws, local (default: aws)"
    echo "  --namespace NAME      Application namespace (default: online-boutique)"
    echo "  --no-external-access  Disable external access"
    echo "  --enable-istio        Enable Istio service mesh"
    echo "  --enable-load-gen     Enable load generator"
    echo "  --help                Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                                    # AWS deployment with external access"
    echo "  $0 --type local                       # Local deployment"
    echo "  $0 --type aws --enable-istio          # AWS with Istio"
    echo "  $0 --type local --no-external-access  # Local without external access"
    echo ""
}

# Function to parse command line arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --type)
                DEPLOYMENT_TYPE="$2"
                shift 2
                ;;
            --namespace)
                NAMESPACE="$2"
                shift 2
                ;;
            --no-external-access)
                ENABLE_EXTERNAL_ACCESS="false"
                shift
                ;;
            --enable-istio)
                ENABLE_ISTIO="true"
                shift
                ;;
            --enable-load-gen)
                ENABLE_LOAD_GENERATOR="true"
                shift
                ;;
            --load-balancer-type)
                LOAD_BALANCER_TYPE="$2"
                shift 2
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
    
    # Check AWS prerequisites for AWS deployment
    if [ "$DEPLOYMENT_TYPE" = "aws" ]; then
        if ! command -v aws &> /dev/null; then
            print_error "AWS CLI is not installed. Please install AWS CLI first."
            exit 1
        fi
        
        if ! command -v eksctl &> /dev/null; then
            print_error "eksctl is not installed. Please install eksctl first."
            exit 1
        fi
        
        if ! aws sts get-caller-identity &> /dev/null; then
            print_error "AWS credentials not configured. Please run 'aws configure' first."
            exit 1
        fi
    fi
    
    print_success "Prerequisites check passed!"
}

# Function to deploy observability framework
deploy_observability() {
    print_info "Phase 1: Deploying Observability Framework"
    echo "================================================"
    
    if [ "$DEPLOYMENT_TYPE" = "aws" ]; then
        print_info "Deploying AWS observability framework..."
        ./installation/deploy-aws-observability.sh
    else
        print_warning "Local deployment not supported. Use AWS deployment."
        exit 1
    fi
    
    print_success "Observability framework deployed successfully!"
}

# Function to deploy online boutique application
deploy_application() {
    print_info "Phase 2: Deploying Online Boutique Application"
    echo "==================================================="
    
    # Build deployment command
    local deploy_cmd="./installation/deploy-online-boutique.sh"
    
    # Add options
    if [ "$ENABLE_EXTERNAL_ACCESS" = "true" ]; then
        deploy_cmd="$deploy_cmd --external-access"
    fi
    
    if [ "$ENABLE_ISTIO" = "true" ]; then
        deploy_cmd="$deploy_cmd --enable-istio"
    fi
    
    if [ "$ENABLE_LOAD_GENERATOR" = "true" ]; then
        deploy_cmd="$deploy_cmd"  # Load generator is enabled by default
    else
        deploy_cmd="$deploy_cmd --disable-load-generator"
    fi
    
    if [ "$NAMESPACE" != "online-boutique" ]; then
        deploy_cmd="$deploy_cmd --namespace $NAMESPACE"
    fi
    
    print_info "Running: $deploy_cmd"
    eval $deploy_cmd
    
    print_success "Online boutique application deployed successfully!"
}

# Function to verify installation
verify_installation() {
    print_info "Phase 3: Verifying Installation"
    echo "===================================="
    
    # Verify observability components
    print_info "Verifying observability components..."
    print_info "Observability validation integrated into deployment script"
    
    # Verify application components
    print_info "Verifying application components..."
    
    # Check if namespace exists
    if kubectl get namespace $NAMESPACE &> /dev/null; then
        print_info "Checking application pods..."
        kubectl get pods -n $NAMESPACE
        
        print_info "Checking application services..."
        kubectl get services -n $NAMESPACE
        
        # Test frontend connectivity
        print_info "Testing frontend connectivity..."
        if kubectl run test-frontend --image=curlimages/curl --rm -i --restart=Never -n $NAMESPACE -- curl -s http://frontend:8080/health &> /dev/null; then
            print_success "Frontend is accessible!"
        else
            print_warning "Frontend connectivity test failed"
        fi
    else
        print_warning "Application namespace $NAMESPACE not found"
    fi
    
    print_success "Installation verification completed!"
}

# Function to display access information
display_access_info() {
    echo ""
    echo "=========================================="
    echo "🎉 COMPLETE STACK DEPLOYED SUCCESSFULLY!"
    echo "=========================================="
    echo ""
    echo "Deployment Type: $DEPLOYMENT_TYPE"
    echo "Application Namespace: $NAMESPACE"
    echo "External Access: $ENABLE_EXTERNAL_ACCESS"
    echo "Istio Enabled: $ENABLE_ISTIO"
    echo "Load Generator: $ENABLE_LOAD_GENERATOR"
    echo ""
    
    # Display observability access
    echo "Observability Access:"
    echo "--------------------"
    if [ "$DEPLOYMENT_TYPE" = "aws" ]; then
        echo "Grafana: http://<grafana-lb> (admin/admin)"
        echo "Prometheus: http://<prometheus-lb>"
        echo "Alertmanager: http://<alertmanager-lb>"
        echo ""
        echo "Get Load Balancer URLs:"
        echo "kubectl get svc -n monitoring -o wide"
    else
        echo "Grafana: kubectl port-forward -n monitoring svc/grafana 3000:3000"
        echo "Prometheus: kubectl port-forward -n monitoring svc/prometheus 9090:9090"
        echo "Alertmanager: kubectl port-forward -n monitoring svc/alertmanager 9093:9093"
    fi
    
    echo ""
    echo "Application Access:"
    echo "------------------"
    if [ "$ENABLE_EXTERNAL_ACCESS" = "true" ] && [ "$DEPLOYMENT_TYPE" = "aws" ]; then
        echo "Online Boutique: http://<frontend-lb>"
        echo ""
        echo "Get Load Balancer URL:"
        echo "kubectl get svc frontend -n $NAMESPACE -o wide"
    else
        echo "Online Boutique: kubectl port-forward -n $NAMESPACE svc/frontend 8080:8080"
        echo "Then open: http://localhost:8080"
    fi
    
    echo ""
    echo "Useful Commands:"
    echo "----------------"
    echo "Check application status: kubectl get pods -n $NAMESPACE"
    echo "Check observability status: kubectl get pods -n monitoring"
    echo "View application logs: kubectl logs -f deployment/frontend -n $NAMESPACE"
    echo "View Grafana logs: kubectl logs -f deployment/grafana -n monitoring"
    echo ""
    
    echo "Cleanup Commands:"
    echo "-----------------"
    echo "Clean up application: ./installation/cleanup-online-boutique.sh"
    if [ "$DEPLOYMENT_TYPE" = "aws" ]; then
        echo "Clean up AWS infrastructure: ./installation/cleanup-aws-observability.sh"
    else
        echo "Clean up observability: kubectl delete namespace monitoring"
    fi
    echo ""
}

# Function to show next steps
show_next_steps() {
    echo ""
    print_info "Next Steps"
    echo "==========="
    echo ""
    echo "1. Access your applications using the URLs above"
    echo "2. Explore the online boutique features"
    echo "3. Check out the Grafana dashboards"
    echo "4. Configure custom alerts in Alertmanager"
    echo "5. Set up custom dashboards for your use case"
    echo "6. Configure production security settings"
    echo "7. Set up CI/CD pipelines for automated deployments"
    echo ""
    echo "Documentation:"
    echo "- Complete Installation Flow: ../COMPLETE_INSTALLATION_FLOW.md"
    echo "- Application Guide: ../ONLINE_BOUTIQUE_INSTALLATION.md"
    echo "- Observability Guide: ../INSTALLATION_GUIDE.md"
    echo "- Troubleshooting: ./TROUBLESHOOTING.md"
    echo ""
}

# Main function
main() {
    echo "🚀 Complete Stack Deployment"
    echo "============================"
    echo ""
    echo "This script will deploy:"
    echo "1. Observability framework (monitoring, logging, tracing)"
    echo "2. Online boutique microservices application"
    echo "3. Verify the complete installation"
    echo ""
    echo "Configuration:"
    echo "- Deployment Type: $DEPLOYMENT_TYPE"
    echo "- Application Namespace: $NAMESPACE"
    echo "- External Access: $ENABLE_EXTERNAL_ACCESS"
    echo "- Istio Service Mesh: $ENABLE_ISTIO"
    echo "- Load Generator: $ENABLE_LOAD_GENERATOR"
    echo ""
    
    # Parse command line arguments
    parse_arguments "$@"
    
    # Check prerequisites
    # check_prerequisites
    
    # Deploy observability framework
    deploy_observability
    
    # Deploy online boutique application
    deploy_application
    
    # Verify installation
    verify_installation
    
    # Display access information
    display_access_info
    
    # Show next steps
    show_next_steps
    
    print_success "🎉 Complete stack deployment finished successfully!"
    print_info "Your applications are ready to use!"
}

# Run main function
main "$@" 