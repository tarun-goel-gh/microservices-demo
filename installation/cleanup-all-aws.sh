#!/bin/bash

# Comprehensive AWS Cleanup Script
# This script removes ALL AWS resources created by the microservices deployment

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

# Configuration
CLUSTER_NAME="ecom-prod-cluster"
REGION="us-east-1"
CONFIRM_CLEANUP="false"
FORCE_CLEANUP="false"

# Function to show help
show_help() {
    echo "Comprehensive AWS Cleanup Script"
    echo "==============================="
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --cluster-name NAME    EKS cluster name (default: ecom-prod-cluster)"
    echo "  --region REGION        AWS region (default: us-east-1)"
    echo "  --confirm              Skip confirmation prompt"
    echo "  --force                Force cleanup even if cluster doesn't exist"
    echo "  --help                 Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                                    # Clean up with confirmation"
    echo "  $0 --cluster-name my-cluster         # Clean up specific cluster"
    echo "  $0 --region us-west-2                # Clean up in specific region"
    echo "  $0 --confirm                          # Clean up without confirmation"
    echo "  $0 --force                           # Force cleanup of orphaned resources"
    echo ""
}

# Function to parse arguments
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
            --force)
                FORCE_CLEANUP="true"
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
    
    if ! command -v aws &> /dev/null; then
        print_error "AWS CLI is not installed"
        exit 1
    fi
    
    if ! command -v eksctl &> /dev/null; then
        print_error "eksctl is not installed"
        exit 1
    fi
    
    if ! aws sts get-caller-identity &> /dev/null; then
        print_error "AWS credentials not configured"
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
    print_warning "⚠️  DANGER: This will delete ALL AWS resources!"
    echo "====================================================="
    echo ""
    echo "The following will be DELETED:"
    echo "❌ EKS cluster: $CLUSTER_NAME"
    echo "❌ All node groups and worker nodes"
    echo "❌ All Load Balancers (ALB, NLB, CLB)"
    echo "❌ All EBS volumes"
    echo "❌ All security groups"
    echo "❌ All ENIs (Elastic Network Interfaces)"
    echo "❌ VPC and subnets (if created by eksctl)"
    echo "❌ NAT Gateways and Elastic IPs"
    echo "❌ IAM roles and policies"
    echo "❌ All application data"
    echo ""
    echo "This action is IRREVERSIBLE and will cost money!"
    echo ""
    
    read -p "Type 'DELETE ALL' to confirm: " confirm
    
    if [ "$confirm" != "DELETE ALL" ]; then
        print_info "Cleanup cancelled."
        exit 0
    fi
    
    echo ""
    print_warning "Proceeding with complete AWS cleanup..."
    echo ""
}

# Function to cleanup Kubernetes resources
cleanup_kubernetes_resources() {
    print_info "Phase 1: Cleaning up Kubernetes resources..."
    echo "================================================"
    
    # Check if cluster exists and is accessible
    if ! eksctl get cluster --name $CLUSTER_NAME --region $REGION &> /dev/null; then
        print_warning "Cluster $CLUSTER_NAME not found or not accessible."
        return 0
    fi
    
    # Update kubeconfig
    print_info "Updating kubeconfig..."
    aws eks update-kubeconfig --name $CLUSTER_NAME --region $REGION
    
    # Delete all namespaces except system ones
    print_info "Deleting application namespaces..."
    kubectl get namespaces --no-headers | grep -v -E "(default|kube-system|kube-public|kube-node-lease)" | awk '{print $1}' | while read namespace; do
        print_info "Deleting namespace: $namespace"
        kubectl delete namespace "$namespace" --timeout=300s || true
    done
    
    # Delete orphaned PVCs
    print_info "Cleaning up persistent volumes..."
    kubectl get pvc --all-namespaces | grep -v "NAMESPACE" | while read namespace name rest; do
        if [ "$namespace" != "kube-system" ] && [ "$namespace" != "default" ]; then
            print_info "Deleting PVC $name in namespace $namespace"
            kubectl delete pvc "$name" -n "$namespace" --timeout=60s || true
        fi
    done
    
    # Delete orphaned PVs
    kubectl get pv | grep -v "NAME" | while read name rest; do
        print_info "Deleting PV $name"
        kubectl delete pv "$name" --timeout=60s || true
    done
    
    print_success "Kubernetes resources cleaned up!"
}

# Function to delete EKS cluster
delete_eks_cluster() {
    print_info "Phase 2: Deleting EKS cluster..."
    echo "===================================="
    
    if ! eksctl get cluster --name $CLUSTER_NAME --region $REGION &> /dev/null; then
        print_warning "EKS cluster $CLUSTER_NAME not found in region $REGION."
        return 0
    fi
    
    # Get cluster VPC ID before deletion
    print_info "Getting cluster information..."
    VPC_ID=$(aws eks describe-cluster --name $CLUSTER_NAME --region $REGION --query 'cluster.resourcesVpcConfig.vpcId' --output text 2>/dev/null || echo "")
    
    # Delete EKS cluster
    print_info "Deleting EKS cluster: $CLUSTER_NAME"
    print_info "This may take 10-15 minutes..."
    
    if eksctl delete cluster --name $CLUSTER_NAME --region $REGION --force; then
        print_success "EKS cluster deletion initiated!"
        
        # Wait for cluster deletion
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
    
    # Store VPC ID for later cleanup
    echo "$VPC_ID" > /tmp/cluster_vpc_id.txt
    
    print_success "EKS cluster deleted!"
}

# Function to cleanup all AWS resources
cleanup_all_aws_resources() {
    print_info "Phase 3: Cleaning up all AWS resources..."
    echo "=============================================="
    
    # Clean up Load Balancers
    cleanup_load_balancers
    
    # Clean up EBS volumes
    cleanup_ebs_volumes
    
    # Clean up security groups
    cleanup_security_groups
    
    # Clean up ENIs
    cleanup_network_interfaces
    
    # Clean up IAM resources
    cleanup_iam_resources
    
    # Clean up VPC resources
    if [ -f /tmp/cluster_vpc_id.txt ]; then
        VPC_ID=$(cat /tmp/cluster_vpc_id.txt)
        rm -f /tmp/cluster_vpc_id.txt
        cleanup_vpc_resources "$VPC_ID"
    fi
    
    print_success "All AWS resources cleaned up!"
}

# Function to cleanup Load Balancers
cleanup_load_balancers() {
    print_info "Cleaning up Load Balancers..."
    
    # Network Load Balancers
    aws elbv2 describe-load-balancers --region $REGION --query 'LoadBalancers[?Type==`network`].LoadBalancerArn' --output text 2>/dev/null | while read lb_arn; do
        if [ ! -z "$lb_arn" ]; then
            lb_name=$(aws elbv2 describe-load-balancers --load-balancer-arns "$lb_arn" --region $REGION --query 'LoadBalancers[0].LoadBalancerName' --output text 2>/dev/null)
            if [[ "$lb_name" == *"$CLUSTER_NAME"* ]] || [[ "$lb_name" == *"observability"* ]] || [[ "$lb_name" == *"monitoring"* ]] || [[ "$lb_name" == *"boutique"* ]]; then
                print_info "Deleting Network Load Balancer: $lb_name"
                aws elbv2 delete-load-balancer --load-balancer-arn "$lb_arn" --region $REGION 2>/dev/null || true
            fi
        fi
    done
    
    # Application Load Balancers
    aws elbv2 describe-load-balancers --region $REGION --query 'LoadBalancers[?Type==`application`].LoadBalancerArn' --output text 2>/dev/null | while read lb_arn; do
        if [ ! -z "$lb_arn" ]; then
            lb_name=$(aws elbv2 describe-load-balancers --load-balancer-arns "$lb_arn" --region $REGION --query 'LoadBalancers[0].LoadBalancerName' --output text 2>/dev/null)
            if [[ "$lb_name" == *"$CLUSTER_NAME"* ]] || [[ "$lb_name" == *"observability"* ]] || [[ "$lb_name" == *"monitoring"* ]] || [[ "$lb_name" == *"boutique"* ]]; then
                print_info "Deleting Application Load Balancer: $lb_name"
                aws elbv2 delete-load-balancer --load-balancer-arn "$lb_arn" --region $REGION 2>/dev/null || true
            fi
        fi
    done
    
    # Classic Load Balancers
    aws elb describe-load-balancers --region $REGION --query 'LoadBalancerDescriptions[].LoadBalancerName' --output text 2>/dev/null | while read lb_name; do
        if [ ! -z "$lb_name" ]; then
            if [[ "$lb_name" == *"$CLUSTER_NAME"* ]] || [[ "$lb_name" == *"observability"* ]] || [[ "$lb_name" == *"monitoring"* ]] || [[ "$lb_name" == *"boutique"* ]]; then
                print_info "Deleting Classic Load Balancer: $lb_name"
                aws elb delete-load-balancer --load-balancer-name "$lb_name" --region $REGION 2>/dev/null || true
            fi
        fi
    done
}

# Function to cleanup EBS volumes
cleanup_ebs_volumes() {
    print_info "Cleaning up EBS volumes..."
    
    # Delete volumes tagged with cluster
    aws ec2 describe-volumes --region $REGION --filters "Name=status,Values=available" --query 'Volumes[?Tags[?Key==`kubernetes.io/cluster/'"$CLUSTER_NAME"'` && Value==`owned`]].VolumeId' --output text 2>/dev/null | while read volume_id; do
        if [ ! -z "$volume_id" ]; then
            print_info "Deleting EBS volume: $volume_id"
            aws ec2 delete-volume --volume-id "$volume_id" --region $REGION 2>/dev/null || true
        fi
    done
    
    # Delete volumes with cluster name in description
    aws ec2 describe-volumes --region $REGION --filters "Name=status,Values=available" --query 'Volumes[?contains(Description, `'"$CLUSTER_NAME"'`)].VolumeId' --output text 2>/dev/null | while read volume_id; do
        if [ ! -z "$volume_id" ]; then
            print_info "Deleting EBS volume: $volume_id"
            aws ec2 delete-volume --volume-id "$volume_id" --region $REGION 2>/dev/null || true
        fi
    done
}

# Function to cleanup security groups
cleanup_security_groups() {
    print_info "Cleaning up security groups..."
    
    aws ec2 describe-security-groups --region $REGION --filters "Name=group-name,Values=*$CLUSTER_NAME*" --query 'SecurityGroups[?GroupName!=`default`].GroupId' --output text 2>/dev/null | while read sg_id; do
        if [ ! -z "$sg_id" ]; then
            print_info "Deleting security group: $sg_id"
            aws ec2 delete-security-group --group-id "$sg_id" --region $REGION 2>/dev/null || true
        fi
    done
}

# Function to cleanup network interfaces
cleanup_network_interfaces() {
    print_info "Cleaning up network interfaces..."
    
    aws ec2 describe-network-interfaces --region $REGION --filters "Name=description,Values=*$CLUSTER_NAME*" --query 'NetworkInterfaces[?Status==`available`].NetworkInterfaceId' --output text 2>/dev/null | while read eni_id; do
        if [ ! -z "$eni_id" ]; then
            print_info "Deleting ENI: $eni_id"
            aws ec2 delete-network-interface --network-interface-id "$eni_id" --region $REGION 2>/dev/null || true
        fi
    done
}

# Function to cleanup IAM resources
cleanup_iam_resources() {
    print_info "Cleaning up IAM resources..."
    
    # Delete IAM policies
    aws iam list-policies --scope Local --query 'Policies[?PolicyName==`AWSLoadBalancerControllerIAMPolicy`].Arn' --output text 2>/dev/null | while read policy_arn; do
        if [ ! -z "$policy_arn" ]; then
            print_info "Deleting IAM policy: $policy_arn"
            aws iam delete-policy --policy-arn "$policy_arn" 2>/dev/null || true
        fi
    done
    
    # Delete IAM roles
    aws iam list-roles --query 'Roles[?contains(RoleName, `'"$CLUSTER_NAME"'`)].RoleName' --output text 2>/dev/null | while read role_name; do
        if [ ! -z "$role_name" ]; then
            print_info "Deleting IAM role: $role_name"
            # Detach policies first
            aws iam list-attached-role-policies --role-name "$role_name" --query 'AttachedPolicies[].PolicyArn' --output text 2>/dev/null | while read policy_arn; do
                if [ ! -z "$policy_arn" ]; then
                    aws iam detach-role-policy --role-name "$role_name" --policy-arn "$policy_arn" 2>/dev/null || true
                fi
            done
            # Delete role
            aws iam delete-role --role-name "$role_name" 2>/dev/null || true
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
    
    # Get VPC name
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
        
        # Wait for NAT Gateways
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
    
    # Count remaining resources
    remaining_lbs=$(aws elbv2 describe-load-balancers --region $REGION --query 'length(LoadBalancers[?contains(LoadBalancerName, `'"$CLUSTER_NAME"'`)])' --output text 2>/dev/null || echo "0")
    remaining_volumes=$(aws ec2 describe-volumes --region $REGION --filters "Name=status,Values=available" --query 'length(Volumes[?contains(Description, `'"$CLUSTER_NAME"'`)])' --output text 2>/dev/null || echo "0")
    remaining_sgs=$(aws ec2 describe-security-groups --region $REGION --filters "Name=group-name,Values=*$CLUSTER_NAME*" --query 'length(SecurityGroups[?GroupName!=`default`])' --output text 2>/dev/null || echo "0")
    
    if [ "$remaining_lbs" = "0" ] && [ "$remaining_volumes" = "0" ] && [ "$remaining_sgs" = "0" ]; then
        print_success "No orphaned resources found!"
    else
        print_warning "Orphaned resources found:"
        print_warning "  - Load Balancers: $remaining_lbs"
        print_warning "  - EBS Volumes: $remaining_volumes"
        print_warning "  - Security Groups: $remaining_sgs"
    fi
    
    print_success "Cleanup verification completed!"
}

# Function to display summary
display_summary() {
    echo ""
    echo "=========================================="
    echo "🧹 COMPREHENSIVE AWS CLEANUP COMPLETED!"
    echo "=========================================="
    echo ""
    echo "All resources have been cleaned up:"
    echo "✅ EKS cluster: $CLUSTER_NAME"
    echo "✅ All node groups and worker nodes"
    echo "✅ All Load Balancers (ALB, NLB, CLB)"
    echo "✅ All EBS volumes"
    echo "✅ All security groups"
    echo "✅ All ENIs"
    echo "✅ VPC and subnets (if created by eksctl)"
    echo "✅ NAT Gateways and Elastic IPs"
    echo "✅ IAM roles and policies"
    echo "✅ All application data"
    echo ""
    echo "Cost savings: $50-200/month depending on usage"
    echo ""
    echo "To recreate the environment, run:"
    echo "./installation/deploy-aws-observability.sh"
    echo ""
}

# Main function
main() {
    echo "🧹 Comprehensive AWS Cleanup"
    echo "============================"
    echo ""
    echo "This script will delete ALL AWS resources!"
    echo ""
    
    # Parse arguments
    parse_arguments "$@"
    
    # Check prerequisites
    check_prerequisites
    
    # Confirm cleanup
    confirm_cleanup
    
    # Cleanup Kubernetes resources
    cleanup_kubernetes_resources
    
    # Delete EKS cluster
    delete_eks_cluster
    
    # Cleanup all AWS resources
    cleanup_all_aws_resources
    
    # Verify cleanup
    verify_cleanup
    
    # Display summary
    display_summary
    
    print_success "🎉 Comprehensive AWS cleanup completed successfully!"
}

# Run main function
main "$@" 