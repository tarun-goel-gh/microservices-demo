#!/bin/bash

# AWS Observability Framework Cleanup Script
# This script removes all AWS resources and observability components

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
CONFIRM_CLEANUP="false"

# Function to show help
show_help() {
    echo "AWS Observability Framework Cleanup Script"
    echo "=========================================="
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --cluster-name NAME    EKS cluster name (default: ecom-prod-cluster)"
    echo "  --region REGION        AWS region (default: us-east-1)"
    echo "  --confirm              Skip confirmation prompt"
    echo "  --help                 Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                                    # Clean up with confirmation"
    echo "  $0 --cluster-name my-cluster         # Clean up specific cluster"
    echo "  $0 --region us-west-2                # Clean up in specific region"
    echo "  $0 --confirm                          # Clean up without confirmation"
    echo ""
}

# Function to parse command line arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --cluster-name)
                CLUSTER_NAME="$2"
                shift 2
                ;;
            --region)
                REGION="$2"
                shift 2
                ;;
            --confirm)
                CONFIRM_CLEANUP="true"
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

# Function to check prerequisites
check_prerequisites() {
    print_info "Checking prerequisites..."
    
    # Check AWS CLI
    if ! command -v aws &> /dev/null; then
        print_error "AWS CLI is not installed."
        exit 1
    fi
    
    # Check eksctl
    if ! command -v eksctl &> /dev/null; then
        print_error "eksctl is not installed."
        exit 1
    fi
    
    # Check AWS credentials
    if ! aws sts get-caller-identity &> /dev/null; then
        print_error "AWS credentials not configured."
        exit 1
    fi
    
    print_success "Prerequisites check passed!"
}

# Function to confirm cleanup
confirm_cleanup() {
    if [ "$CONFIRM_CLEANUP" = "true" ]; then
        return 0
    fi
    
    echo ""
    print_warning "⚠️  WARNING: This will delete all AWS resources and data!"
    echo "================================================================"
    echo ""
    echo "The following resources will be deleted:"
    echo "- EKS cluster: $CLUSTER_NAME"
    echo "- All node groups"
    echo "- Load Balancers"
    echo "- EBS volumes"
    echo "- IAM roles and policies"
    echo "- VPC and subnets (if created by eksctl)"
    echo "- All observability data (metrics, logs, traces)"
    echo ""
    echo "This action is IRREVERSIBLE!"
    echo ""
    
    read -p "Are you sure you want to continue? (yes/no): " confirm
    
    if [ "$confirm" != "yes" ]; then
        print_info "Cleanup cancelled."
        exit 0
    fi
    
    echo ""
    print_warning "Proceeding with cleanup..."
    echo ""
}

# Function to cleanup observability components
cleanup_observability_components() {
    print_info "Phase 1: Cleaning up observability components..."
    echo "====================================================="
    
    # Check if cluster exists and is accessible
    if ! eksctl get cluster --name $CLUSTER_NAME --region $REGION &> /dev/null; then
        print_warning "Cluster $CLUSTER_NAME not found or not accessible."
        return 0
    fi
    
    # Update kubeconfig
    print_info "Updating kubeconfig..."
    aws eks update-kubeconfig --name $CLUSTER_NAME --region $REGION
    
    # Delete observability components
    print_info "Deleting observability components..."
    
    # Delete all resources in monitoring namespace
    if kubectl get namespace monitoring &> /dev/null; then
        print_info "Deleting monitoring namespace and all resources..."
        kubectl delete namespace monitoring --timeout=300s
    else
        print_info "Monitoring namespace not found."
    fi
    
    # Delete any remaining PVCs
    print_info "Cleaning up persistent volumes..."
    kubectl get pvc --all-namespaces | grep -v "NAMESPACE" | while read namespace name rest; do
        if [ "$namespace" != "kube-system" ] && [ "$namespace" != "default" ]; then
            print_info "Deleting PVC $name in namespace $namespace"
            kubectl delete pvc $name -n $namespace --timeout=60s || true
        fi
    done
    
    # Delete any remaining PVs
    print_info "Cleaning up persistent volumes..."
    kubectl get pv | grep -v "NAME" | while read name rest; do
        print_info "Deleting PV $name"
        kubectl delete pv $name --timeout=60s || true
    done
    
    print_success "Observability components cleaned up!"
}

# Function to cleanup AWS resources
cleanup_aws_resources() {
    print_info "Phase 2: Cleaning up AWS resources..."
    echo "==========================================="
    
    # Check if cluster exists
    if ! eksctl get cluster --name $CLUSTER_NAME --region $REGION &> /dev/null; then
        print_warning "EKS cluster $CLUSTER_NAME not found in region $REGION."
        print_info "Checking for orphaned resources..."
        cleanup_orphaned_resources
        return 0
    fi
    
    # Get cluster VPC ID for cleanup
    print_info "Getting cluster information..."
    VPC_ID=$(aws eks describe-cluster --name $CLUSTER_NAME --region $REGION --query 'cluster.resourcesVpcConfig.vpcId' --output text 2>/dev/null || echo "")
    
    # Delete EKS cluster with proper waiting
    print_info "Deleting EKS cluster: $CLUSTER_NAME"
    print_info "This may take 10-15 minutes..."
    
    if eksctl delete cluster --name $CLUSTER_NAME --region $REGION --force; then
        print_success "EKS cluster deletion initiated!"
        
        # Wait for cluster deletion to complete
        print_info "Waiting for cluster deletion to complete..."
        TIMEOUT=1800  # 30 minutes
        ELAPSED=0
        
        while [ $ELAPSED -lt $TIMEOUT ]; do
            if ! eksctl get cluster --name $CLUSTER_NAME --region $REGION &> /dev/null; then
                print_success "EKS cluster deleted successfully!"
                break
            fi
            
            print_info "Cluster still deleting... (${ELAPSED}s elapsed)"
            sleep 30
            ELAPSED=$((ELAPSED + 30))
        done
        
        if [ $ELAPSED -ge $TIMEOUT ]; then
            print_warning "Cluster deletion timeout. Manual cleanup may be required."
        fi
    else
        print_error "Failed to delete EKS cluster. Manual cleanup required."
        return 1
    fi
    
    # Clean up orphaned resources
    cleanup_orphaned_resources
    
    # Clean up VPC if it was created by eksctl
    if [ ! -z "$VPC_ID" ]; then
        cleanup_vpc_resources "$VPC_ID"
    fi
    
    print_success "AWS resources cleaned up!"
}

# Function to cleanup orphaned resources
cleanup_orphaned_resources() {
    print_info "Cleaning up orphaned AWS resources..."
    
    # Clean up orphaned Load Balancers (both ALB and NLB)
    print_info "Cleaning up orphaned Load Balancers..."
    
    # Network Load Balancers
    aws elbv2 describe-load-balancers --region $REGION --query 'LoadBalancers[?Type==`network`].LoadBalancerArn' --output text 2>/dev/null | while read lb_arn; do
        if [ ! -z "$lb_arn" ]; then
            lb_name=$(aws elbv2 describe-load-balancers --load-balancer-arns "$lb_arn" --region $REGION --query 'LoadBalancers[0].LoadBalancerName' --output text 2>/dev/null)
            if [[ "$lb_name" == *"$CLUSTER_NAME"* ]] || [[ "$lb_name" == *"observability"* ]] || [[ "$lb_name" == *"monitoring"* ]]; then
                print_info "Deleting Network Load Balancer: $lb_name"
                aws elbv2 delete-load-balancer --load-balancer-arn "$lb_arn" --region $REGION 2>/dev/null || true
            fi
        fi
    done
    
    # Application Load Balancers
    aws elbv2 describe-load-balancers --region $REGION --query 'LoadBalancers[?Type==`application`].LoadBalancerArn' --output text 2>/dev/null | while read lb_arn; do
        if [ ! -z "$lb_arn" ]; then
            lb_name=$(aws elbv2 describe-load-balancers --load-balancer-arns "$lb_arn" --region $REGION --query 'LoadBalancers[0].LoadBalancerName' --output text 2>/dev/null)
            if [[ "$lb_name" == *"$CLUSTER_NAME"* ]] || [[ "$lb_name" == *"observability"* ]] || [[ "$lb_name" == *"monitoring"* ]]; then
                print_info "Deleting Application Load Balancer: $lb_name"
                aws elbv2 delete-load-balancer --load-balancer-arn "$lb_arn" --region $REGION 2>/dev/null || true
            fi
        fi
    done
    
    # Classic Load Balancers
    aws elb describe-load-balancers --region $REGION --query 'LoadBalancerDescriptions[].LoadBalancerName' --output text 2>/dev/null | while read lb_name; do
        if [ ! -z "$lb_name" ]; then
            if [[ "$lb_name" == *"$CLUSTER_NAME"* ]] || [[ "$lb_name" == *"observability"* ]] || [[ "$lb_name" == *"monitoring"* ]]; then
                print_info "Deleting Classic Load Balancer: $lb_name"
                aws elb delete-load-balancer --load-balancer-name "$lb_name" --region $REGION 2>/dev/null || true
            fi
        fi
    done
    
    # Clean up orphaned EBS volumes
    print_info "Cleaning up orphaned EBS volumes..."
    aws ec2 describe-volumes --region $REGION --filters "Name=status,Values=available" --query 'Volumes[?Tags[?Key==`kubernetes.io/cluster/'"$CLUSTER_NAME"'` && Value==`owned`]].VolumeId' --output text 2>/dev/null | while read volume_id; do
        if [ ! -z "$volume_id" ]; then
            print_info "Deleting EBS volume: $volume_id"
            aws ec2 delete-volume --volume-id "$volume_id" --region $REGION 2>/dev/null || true
        fi
    done
    
    # Clean up orphaned security groups
    print_info "Cleaning up orphaned security groups..."
    aws ec2 describe-security-groups --region $REGION --filters "Name=group-name,Values=*$CLUSTER_NAME*" --query 'SecurityGroups[?GroupName!=`default`].GroupId' --output text 2>/dev/null | while read sg_id; do
        if [ ! -z "$sg_id" ]; then
            print_info "Deleting security group: $sg_id"
            aws ec2 delete-security-group --group-id "$sg_id" --region $REGION 2>/dev/null || true
        fi
    done
    
    # Clean up orphaned ENIs (Elastic Network Interfaces)
    print_info "Cleaning up orphaned ENIs..."
    aws ec2 describe-network-interfaces --region $REGION --filters "Name=description,Values=*$CLUSTER_NAME*" --query 'NetworkInterfaces[?Status==`available`].NetworkInterfaceId' --output text 2>/dev/null | while read eni_id; do
        if [ ! -z "$eni_id" ]; then
            print_info "Deleting ENI: $eni_id"
            aws ec2 delete-network-interface --network-interface-id "$eni_id" --region $REGION 2>/dev/null || true
        fi
    done
    
    # Clean up orphaned IAM policies
    print_info "Cleaning up orphaned IAM policies..."
    aws iam list-policies --scope Local --query 'Policies[?PolicyName==`AWSLoadBalancerControllerIAMPolicy`].Arn' --output text 2>/dev/null | while read policy_arn; do
        if [ ! -z "$policy_arn" ]; then
            print_info "Deleting IAM policy: $policy_arn"
            aws iam delete-policy --policy-arn "$policy_arn" 2>/dev/null || true
        fi
    done
}

# Function to cleanup VPC resources
cleanup_vpc_resources() {
    local vpc_id="$1"
    
    if [ -z "$vpc_id" ]; then
        return 0
    fi
    
    print_info "Cleaning up VPC resources for VPC: $vpc_id"
    
    # Get VPC name to check if it was created by eksctl
    vpc_name=$(aws ec2 describe-vpcs --vpc-ids "$vpc_id" --region $REGION --query 'Vpcs[0].Tags[?Key==`Name`].Value' --output text 2>/dev/null)
    
    if [[ "$vpc_name" == *"eksctl"* ]] || [[ "$vpc_name" == *"$CLUSTER_NAME"* ]]; then
        print_info "VPC appears to be created by eksctl, cleaning up..."
        
        # Delete NAT Gateways
        aws ec2 describe-nat-gateways --region $REGION --filter "Name=vpc-id,Values=$vpc_id" --query 'NatGateways[?State!=`deleted`].NatGatewayId' --output text 2>/dev/null | while read nat_id; do
            if [ ! -z "$nat_id" ]; then
                print_info "Deleting NAT Gateway: $nat_id"
                aws ec2 delete-nat-gateway --nat-gateway-id "$nat_id" --region $REGION 2>/dev/null || true
            fi
        done
        
        # Wait for NAT Gateways to be deleted
        print_info "Waiting for NAT Gateways to be deleted..."
        sleep 60
        
        # Delete Elastic IPs
        aws ec2 describe-addresses --region $REGION --query 'Addresses[?Domain==`vpc`].AllocationId' --output text 2>/dev/null | while read eip_id; do
            if [ ! -z "$eip_id" ]; then
                print_info "Deleting Elastic IP: $eip_id"
                aws ec2 release-address --allocation-id "$eip_id" --region $REGION 2>/dev/null || true
            fi
        done
        
        # Delete Internet Gateways
        aws ec2 describe-internet-gateways --region $REGION --filters "Name=attachment.vpc-id,Values=$vpc_id" --query 'InternetGateways[].InternetGatewayId' --output text 2>/dev/null | while read igw_id; do
            if [ ! -z "$igw_id" ]; then
                print_info "Detaching and deleting Internet Gateway: $igw_id"
                aws ec2 detach-internet-gateway --internet-gateway-id "$igw_id" --vpc-id "$vpc_id" --region $REGION 2>/dev/null || true
                aws ec2 delete-internet-gateway --internet-gateway-id "$igw_id" --region $REGION 2>/dev/null || true
            fi
        done
        
        # Delete VPC
        print_info "Deleting VPC: $vpc_id"
        aws ec2 delete-vpc --vpc-id "$vpc_id" --region $REGION 2>/dev/null || true
    else
        print_info "VPC $vpc_id was not created by eksctl, skipping VPC deletion"
    fi
}

# Function to cleanup IAM resources
cleanup_iam_resources() {
    print_info "Phase 3: Cleaning up IAM resources..."
    echo "=========================================="
    
    # Delete IAM service accounts
    print_info "Deleting IAM service accounts..."
    
    # EBS CSI Driver service account
    if eksctl get iamserviceaccount --name ebs-csi-controller-sa --namespace kube-system --cluster $CLUSTER_NAME --region $REGION &> /dev/null; then
        eksctl delete iamserviceaccount --name ebs-csi-controller-sa --namespace kube-system --cluster $CLUSTER_NAME --region $REGION
    fi
    
    # AWS Load Balancer Controller service account
    if eksctl get iamserviceaccount --name aws-load-balancer-controller --namespace kube-system --cluster $CLUSTER_NAME --region $REGION &> /dev/null; then
        eksctl delete iamserviceaccount --name aws-load-balancer-controller --namespace kube-system --cluster $CLUSTER_NAME --region $REGION
    fi
    
    # Delete OIDC provider
    print_info "Deleting OIDC provider..."
    eksctl utils delete-iam-oidc-provider --cluster $CLUSTER_NAME --region $REGION || true
    
    print_success "IAM resources cleaned up!"
}

# Function to verify cleanup
verify_cleanup() {
    print_info "Phase 4: Verifying cleanup..."
    echo "================================="
    
    # Check if cluster still exists
    if eksctl get cluster --name $CLUSTER_NAME --region $REGION &> /dev/null; then
        print_warning "Cluster $CLUSTER_NAME still exists. Manual cleanup may be required."
    else
        print_success "Cluster $CLUSTER_NAME successfully deleted."
    fi
    
    # Check for orphaned resources
    print_info "Checking for orphaned resources..."
    
    # Check for orphaned Load Balancers
    orphaned_lbs=$(aws elbv2 describe-load-balancers --region $REGION --query 'LoadBalancers[?contains(LoadBalancerName, `observability`) || contains(LoadBalancerName, `monitoring`)].LoadBalancerName' --output text)
    if [ ! -z "$orphaned_lbs" ]; then
        print_warning "Orphaned Load Balancers found: $orphaned_lbs"
    else
        print_success "No orphaned Load Balancers found."
    fi
    
    # Check for orphaned EBS volumes
    orphaned_volumes=$(aws ec2 describe-volumes --region $REGION --filters "Name=tag:kubernetes.io/cluster/$CLUSTER_NAME,Values=owned" --query 'Volumes[?State==`available`].VolumeId' --output text)
    if [ ! -z "$orphaned_volumes" ]; then
        print_warning "Orphaned EBS volumes found: $orphaned_volumes"
    else
        print_success "No orphaned EBS volumes found."
    fi
    
    print_success "Cleanup verification completed!"
}

# Function to display cleanup summary
display_cleanup_summary() {
    echo ""
    echo "=========================================="
    echo "🧹 AWS OBSERVABILITY FRAMEWORK CLEANUP"
    echo "=========================================="
    echo ""
    echo "Cleanup completed successfully!"
    echo ""
    echo "Resources removed:"
    echo "------------------"
    echo "✅ EKS cluster: $CLUSTER_NAME"
    echo "✅ All node groups"
    echo "✅ Load Balancers"
    echo "✅ EBS volumes"
    echo "✅ IAM roles and policies"
    echo "✅ Observability components"
    echo "✅ All monitoring data"
    echo ""
    echo "Note: Some resources may take a few minutes to be fully removed from AWS."
    echo ""
    echo "To recreate the environment, run:"
    echo "./installation/deploy-aws-observability.sh"
    echo ""
}

# Function to show cost savings
show_cost_savings() {
    echo ""
    print_info "Cost Savings Information"
    echo "============================"
    echo ""
    echo "By cleaning up these resources, you have stopped incurring charges for:"
    echo ""
    echo "1. EKS Cluster:"
    echo "   - Control plane: ~$0.10/hour"
    echo "   - Worker nodes: ~$0.0416/hour per t3.medium"
    echo ""
    echo "2. Load Balancers:"
    echo "   - Network Load Balancer: ~$0.0225/hour"
    echo "   - Data processing: ~$0.006/GB"
    echo ""
    echo "3. EBS Volumes:"
    echo "   - gp3 storage: ~$0.08/GB-month"
    echo "   - IOPS: ~$0.05/provisioned IOPS-month"
    echo ""
    echo "4. Data Transfer:"
    echo "   - Outbound data: ~$0.09/GB"
    echo ""
    echo "Estimated monthly savings: $50-200 depending on usage"
    echo ""
}

# Main function
main() {
    echo "🧹 AWS Observability Framework Cleanup"
    echo "======================================"
    echo ""
    echo "This script will:"
    echo "1. Clean up all observability components"
    echo "2. Delete AWS resources (EKS cluster, Load Balancers, etc.)"
    echo "3. Clean up IAM resources"
    echo "4. Verify the cleanup"
    echo ""
    
    # Parse command line arguments
    parse_arguments "$@"
    
    # Check prerequisites
    check_prerequisites
    
    # Confirm cleanup
    confirm_cleanup
    
    # Cleanup observability components
    cleanup_observability_components
    
    # Cleanup AWS resources
    cleanup_aws_resources
    
    # Cleanup IAM resources
    cleanup_iam_resources
    
    # Verify cleanup
    verify_cleanup
    
    # Display cleanup summary
    display_cleanup_summary
    
    # Show cost savings
    show_cost_savings
    
    print_success "🎉 AWS Observability Framework cleanup completed successfully!"
}

# Run main function
main "$@" 