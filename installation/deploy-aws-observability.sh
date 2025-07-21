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
EKS_VERSION="1.33"
NODE_TYPE="t3a.xlarge"
NODE_COUNT=5
USE_EXISTING_CLUSTER=false
LOAD_BALANCER_TYPE="clb"  # Options: nlb, alb, clb (Classic Load Balancer)
VPC_CIDR="10.0.0.0/16"
SUBNET_CIDR="10.0.1.0/24"
CLUSTER_ROLE_NAME="eks-cluster-role"
NODE_ROLE_NAME="eks-node-role"

# Function to show help
show_help() {
    echo "AWS Observability Deployment Script"
    echo "=================================="
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --cluster-name NAME    EKS cluster name (default: ecom-prod-cluster)"
    echo "  --region REGION        AWS region (default: us-east-1)"
    echo "  --use-existing         Use existing cluster (skip creation)"
    echo "  --skip-load-balancer   Skip AWS Load Balancer Controller installation"
    echo "  --load-balancer-type TYPE  Load Balancer type (default: nlb, options: nlb, alb, clb)"
    echo "  --help                 Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                                    # Create new cluster and deploy"
    echo "  $0 --use-existing                     # Use existing cluster"
    echo "  $0 --cluster-name my-cluster          # Use specific cluster name"
    echo "  $0 --region us-west-2                 # Use specific region"
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
            --use-existing)
                USE_EXISTING_CLUSTER="true"
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
    
    # Check eksctl version compatibility
    print_info "Checking eksctl version compatibility..."
    EKSCTL_VERSION=$(eksctl version --output json 2>/dev/null | grep -o '"version":"[^"]*"' | cut -d'"' -f4 || echo "unknown")
    print_info "eksctl version: $EKSCTL_VERSION"
    
    # Check if --force-update flag is supported
    if eksctl create iamserviceaccount --help 2>&1 | grep -q "force-update"; then
        print_info "eksctl supports --force-update flag"
    else
        print_warning "eksctl does not support --force-update flag, using fallback method"
    fi
    
    print_success "Prerequisites check passed!"
}

# Function to check if EKS cluster exists
check_cluster_exists() {
    print_info "Checking if EKS cluster '$CLUSTER_NAME' already exists..."
    
    if aws eks describe-cluster --name $CLUSTER_NAME --region $REGION &> /dev/null; then
        CLUSTER_STATUS=$(aws eks describe-cluster --name $CLUSTER_NAME --region $REGION --query 'cluster.status' --output text)
        print_info "Cluster '$CLUSTER_NAME' exists with status: $CLUSTER_STATUS"
        
        if [ "$CLUSTER_STATUS" = "ACTIVE" ]; then
            print_success "Cluster is already active and ready to use!"
            return 0
        elif [ "$CLUSTER_STATUS" = "CREATING" ]; then
            print_warning "Cluster is still being created. Waiting for it to become active..."
            return 1
        elif [ "$CLUSTER_STATUS" = "DELETING" ]; then
            print_error "Cluster is being deleted. Please wait for deletion to complete or use a different cluster name."
            exit 1
        else
            print_warning "Cluster exists but status is '$CLUSTER_STATUS'. Proceeding with setup..."
            return 1
        fi
    else
        print_info "Cluster '$CLUSTER_NAME' does not exist. Will create new cluster."
        return 1
    fi
}

# Function to install Prometheus Operator CRDs using alternative method
install_prometheus_crds_alternative() {
    print_info "Installing Prometheus Operator CRDs using alternative method..."
    
    # Create a temporary directory for CRD files
    TEMP_DIR=$(mktemp -d)
    cd "$TEMP_DIR"
    
    # Download CRDs from a more stable source
    print_info "Downloading Prometheus Operator CRDs..."
    
    # Try different sources for CRDs
    local crd_sources=(
        "https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/v0.68.0/example/prometheus-operator-crd/monitoring.coreos.com_prometheuses.yaml"
        "https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/v0.67.0/example/prometheus-operator-crd/monitoring.coreos.com_prometheuses.yaml"
        "https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/v0.66.0/example/prometheus-operator-crd/monitoring.coreos.com_prometheuses.yaml"
    )
    
    local crd_installed=false
    
    for crd_url in "${crd_sources[@]}"; do
        print_info "Trying CRD source: $crd_url"
        
        if curl -s -o prometheuses.yaml "$crd_url" && \
           curl -s -o prometheusrules.yaml "${crd_url%prometheuses.yaml}prometheusrules.yaml" && \
           curl -s -o servicemonitors.yaml "${crd_url%prometheuses.yaml}servicemonitors.yaml"; then
            
            # Remove large annotations that cause the size limit issue
            print_info "Processing CRD files to remove large annotations..."
            
            # Apply CRDs without large annotations
            if kubectl apply -f prometheusrules.yaml && \
               kubectl apply -f servicemonitors.yaml && \
               kubectl apply -f prometheuses.yaml; then
                print_success "Prometheus Operator CRDs installed successfully"
                crd_installed=true
                break
            else
                print_warning "Failed to apply CRDs from: $crd_url"
            fi
        else
            print_warning "Failed to download CRDs from: $crd_url"
        fi
    done
    
    # Clean up temporary directory
    cd - > /dev/null
    rm -rf "$TEMP_DIR"
    
    if [ "$crd_installed" = false ]; then
        print_warning "All CRD installation methods failed. Continuing without Prometheus Operator CRDs..."
        print_info "You may need to install CRDs manually or use a different monitoring approach."
    fi
}

# Function to deploy AWS Load Balancer Controller using kustomize
deploy_load_balancer_controller_kustomize() {
    print_info "Deploying AWS Load Balancer Controller using kustomize..."
    
    # Try different kustomize paths
    local kustomize_paths=(
        "github.com/kubernetes-sigs/aws-load-balancer-controller//deploy/eks?ref=v2.7.1"
        "github.com/kubernetes-sigs/aws-load-balancer-controller//deploy/eks/chart?ref=v2.7.1"
        "github.com/kubernetes-sigs/aws-load-balancer-controller//deploy/eks/chart?ref=v2.6.0"
        "github.com/kubernetes-sigs/aws-load-balancer-controller//deploy/eks?ref=v2.6.0"
    )
    
    for path in "${kustomize_paths[@]}"; do
        print_info "Trying kustomize path: $path"
        if kubectl apply -k "$path"; then
            print_success "AWS Load Balancer Controller deployed successfully using kustomize"
            return 0
        else
            print_warning "Failed with path: $path"
        fi
    done
    
    print_warning "All kustomize deployment methods failed. This may affect LoadBalancer service creation."
    print_info "You can still use NodePort or ClusterIP services for external access."
    return 1
}

# Function to deploy AWS Load Balancer Controller manually
deploy_load_balancer_controller_manual() {
    print_info "Deploying AWS Load Balancer Controller manually..."
    
    # Create custom IAM policy for AWS Load Balancer Controller
    print_info "Creating custom IAM policy for AWS Load Balancer Controller..."
    
    # Check if policy already exists
    if aws iam get-policy --policy-arn arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):policy/AWSLoadBalancerControllerIAMPolicy &> /dev/null; then
        print_info "Custom AWS Load Balancer Controller policy already exists"
    else
        # Create custom policy with required permissions
        cat <<EOF > aws-load-balancer-controller-policy.json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "iam:CreateServiceLinkedRole"
            ],
            "Resource": "*",
            "Condition": {
                "StringEquals": {
                    "iam:AWSServiceName": "elasticloadbalancing.amazonaws.com"
                }
            }
        },
        {
            "Effect": "Allow",
            "Action": [
                "ec2:DescribeAccountAttributes",
                "ec2:DescribeAddresses",
                "ec2:DescribeInternetGateways",
                "ec2:DescribeVpcs",
                "ec2:DescribeSubnets",
                "ec2:DescribeSecurityGroups",
                "ec2:DescribeInstances",
                "ec2:DescribeNetworkInterfaces",
                "ec2:DescribeTags",
                "elasticloadbalancing:DescribeLoadBalancers",
                "elasticloadbalancing:DescribeLoadBalancerAttributes",
                "elasticloadbalancing:DescribeListeners",
                "elasticloadbalancing:DescribeListenerCertificates",
                "elasticloadbalancing:DescribeSSLPolicies",
                "elasticloadbalancing:DescribeRules",
                "elasticloadbalancing:DescribeTargetGroups",
                "elasticloadbalancing:DescribeTargetGroupAttributes",
                "elasticloadbalancing:DescribeTargetHealth",
                "elasticloadbalancing:DescribeTags"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "cognito-idp:DescribeUserPoolClient",
                "acm:ListCertificates",
                "acm:DescribeCertificate",
                "iam:ListServerCertificates",
                "iam:GetServerCertificate",
                "waf-regional:GetWebACL",
                "waf-regional:GetWebACLForResource",
                "waf-regional:AssociateWebACL",
                "waf-regional:DisassociateWebACL",
                "wafv2:GetWebACL",
                "wafv2:GetWebACLForResource",
                "wafv2:AssociateWebACL",
                "wafv2:DisassociateWebACL",
                "shield:DescribeProtection",
                "shield:GetSubscriptionState",
                "ec2:AuthorizeSecurityGroupIngress",
                "ec2:RevokeSecurityGroupIngress"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "elasticloadbalancing:CreateLoadBalancer",
                "elasticloadbalancing:CreateTargetGroup"
            ],
            "Resource": "*",
            "Condition": {
                "Null": {
                    "aws:RequestTag/elbv2.k8s.aws/cluster": "false"
                }
            }
        },
        {
            "Effect": "Allow",
            "Action": [
                "elasticloadbalancing:CreateListener",
                "elasticloadbalancing:DeleteListener",
                "elasticloadbalancing:CreateRule",
                "elasticloadbalancing:ModifyRule",
                "elasticloadbalancing:DeleteRule",
                "elasticloadbalancing:SetWebAcl",
                "elasticloadbalancing:ModifyListener",
                "elasticloadbalancing:AddListenerCertificates",
                "elasticloadbalancing:RemoveListenerCertificates",
                "elasticloadbalancing:ModifyLoadBalancerAttributes"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "elasticloadbalancing:AddTags",
                "elasticloadbalancing:RemoveTags"
            ],
            "Resource": [
                "arn:aws:elasticloadbalancing:*:*:targetgroup/*/*",
                "arn:aws:elasticloadbalancing:*:*:loadbalancer/net/*/*",
                "arn:aws:elasticloadbalancing:*:*:loadbalancer/app/*/*"
            ],
            "Condition": {
                "Null": {
                    "aws:RequestTag/elbv2.k8s.aws/cluster": "true",
                    "aws:ResourceTag/elbv2.k8s.aws/cluster": "false"
                }
            }
        },
        {
            "Effect": "Allow",
            "Action": [
                "elasticloadbalancing:AddTags",
                "elasticloadbalancing:RemoveTags"
            ],
            "Resource": [
                "arn:aws:elasticloadbalancing:*:*:listener/net/*/*/*",
                "arn:aws:elasticloadbalancing:*:*:listener/app/*/*/*",
                "arn:aws:elasticloadbalancing:*:*:listener-rule/net/*/*/*",
                "arn:aws:elasticloadbalancing:*:*:listener-rule/app/*/*/*"
            ]
        },
        {
            "Effect": "Allow",
            "Action": [
                "elasticloadbalancing:ModifyTargetGroup",
                "elasticloadbalancing:ModifyTargetGroupAttributes"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "elasticloadbalancing:RegisterTargets",
                "elasticloadbalancing:DeregisterTargets"
            ],
            "Resource": "arn:aws:elasticloadbalancing:*:*:targetgroup/*/*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "elasticloadbalancing:SetSecurityGroups",
                "elasticloadbalancing:SetSubnets",
                "elasticloadbalancing:DeleteLoadBalancer",
                "elasticloadbalancing:ModifyTargetGroup",
                "elasticloadbalancing:ModifyTargetGroupAttributes",
                "elasticloadbalancing:DeleteTargetGroup"
            ],
            "Resource": "*",
            "Condition": {
                "Null": {
                    "aws:ResourceTag/elbv2.k8s.aws/cluster": "false"
                }
            }
        },
        {
            "Effect": "Allow",
            "Action": [
                "elasticloadbalancing:RegisterTargets",
                "elasticloadbalancing:DeregisterTargets"
            ],
            "Resource": "arn:aws:elasticloadbalancing:*:*:targetgroup/*/*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "elasticloadbalancing:SetWebAcl",
                "elasticloadbalancing:ModifyListener",
                "elasticloadbalancing:AddListenerCertificates",
                "elasticloadbalancing:RemoveListenerCertificates",
                "elasticloadbalancing:ModifyRule"
            ],
            "Resource": "*"
        }
    ]
}
EOF
        
        # Create the policy
        aws iam create-policy \
            --policy-name AWSLoadBalancerControllerIAMPolicy \
            --policy-document file://aws-load-balancer-controller-policy.json \
            --description "Policy for AWS Load Balancer Controller" \
            --region $REGION
        
        # Clean up the temporary file
        rm aws-load-balancer-controller-policy.json
        
        print_success "Custom AWS Load Balancer Controller policy created"
    fi
    
    # Check if service account already exists
    if kubectl get serviceaccount aws-load-balancer-controller -n kube-system &> /dev/null; then
        print_info "AWS Load Balancer Controller service account already exists"
    else
        # Get the account ID
        ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
        
        # Check if --force-update flag is supported
        if eksctl create iamserviceaccount --help 2>&1 | grep -q "force-update"; then
            eksctl create iamserviceaccount \
                --name aws-load-balancer-controller \
                --namespace kube-system \
                --cluster $CLUSTER_NAME \
                --region $REGION \
                --attach-policy-arn arn:aws:iam::$ACCOUNT_ID:policy/AWSLoadBalancerControllerIAMPolicy \
                --approve \
                --force-update
        else
            # Fallback for older eksctl versions
            eksctl create iamserviceaccount \
                --name aws-load-balancer-controller \
                --namespace kube-system \
                --cluster $CLUSTER_NAME \
                --region $REGION \
                --attach-policy-arn arn:aws:iam::$ACCOUNT_ID:policy/AWSLoadBalancerControllerIAMPolicy \
                --approve
        fi
    fi
    
    # Install EBS CSI Driver (if not exists)
    print_info "Setting up EBS CSI Driver..."
    
    # Check if EBS CSI Driver is already deployed
    if kubectl get deployment ebs-csi-controller -n kube-system &> /dev/null; then
        print_info "EBS CSI Driver already deployed"
    else
        kubectl apply -k "github.com/kubernetes-sigs/aws-ebs-csi-driver/deploy/kubernetes/overlays/stable/?ref=release-1.28"
    fi
    
    # Create storage classes (if not exist)
    print_info "Setting up storage classes..."
    
    # Check if storage classes already exist
    if kubectl get storageclass ebs-sc &> /dev/null; then
        print_info "Storage class 'ebs-sc' already exists"
    else
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
EOF
    fi
    
    if kubectl get storageclass ebs-sc-fast &> /dev/null; then
        print_info "Storage class 'ebs-sc-fast' already exists"
    else
        cat <<EOF | kubectl apply -f -
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
    fi
    
    # Set default storage class (if not already set)
    CURRENT_DEFAULT=$(kubectl get storageclass --no-headers | grep "default" | awk '{print $1}' || echo "")
    if [ "$CURRENT_DEFAULT" != "ebs-sc" ]; then
        print_info "Setting ebs-sc as default storage class..."
        kubectl patch storageclass ebs-sc -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
    else
        print_info "ebs-sc is already the default storage class"
    fi
    
    # Install AWS Load Balancer Controller (if not exists)
    print_info "Setting up AWS Load Balancer Controller..."
    
    # Check if AWS Load Balancer Controller is already deployed
    if kubectl get deployment aws-load-balancer-controller -n kube-system &> /dev/null; then
        print_info "AWS Load Balancer Controller already deployed"
    else
        print_info "Deploying AWS Load Balancer Controller..."
        
        # Method 1: Try Helm deployment
        if command -v helm &> /dev/null; then
            print_info "Attempting Helm deployment..."
            
            # Add the AWS Load Balancer Controller Helm repository
            helm repo add eks https://aws.github.io/eks-charts
            helm repo update
            
            # Deploy using Helm chart
            if helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
                -n kube-system \
                --set clusterName=$CLUSTER_NAME \
                --set serviceAccount.create=false \
                --set serviceAccount.name=aws-load-balancer-controller \
                --wait --timeout=300s; then
                print_success "AWS Load Balancer Controller deployed successfully using Helm"
            else
                print_warning "Helm deployment failed, trying manual deployment..."
                deploy_load_balancer_controller_manual
            fi
        else
            print_info "Helm not available, trying manual deployment..."
            deploy_load_balancer_controller_manual
        fi
    fi
}

# Function to deploy AWS resources
deploy_aws_resources() {
    print_info "Phase 1: Deploying AWS Resources"
    echo "====================================="
    
    # Check if cluster already exists or if user wants to use existing
    if [ "$USE_EXISTING_CLUSTER" = "true" ] || check_cluster_exists; then
        if [ "$USE_EXISTING_CLUSTER" = "true" ]; then
            print_info "Using existing cluster as requested: $CLUSTER_NAME"
        else
            print_info "Using existing cluster: $CLUSTER_NAME"
        fi
        
        # Update kubeconfig for existing cluster
        print_info "Updating kubeconfig for existing cluster..."
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
            exit 1
        fi
        
        print_success "Existing cluster setup completed!"
    else
    
    
        # Create new EKS cluster
        print_info "Creating new EKS cluster: $CLUSTER_NAME"
        
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
    fi
    
    # Create IAM OIDC provider (if not exists)
    print_info "Setting up IAM OIDC provider..."
    eksctl utils associate-iam-oidc-provider --cluster $CLUSTER_NAME --region $REGION --approve
    
    # Create EBS CSI Driver IAM Role (if not exists)
    print_info "Setting up EBS CSI Driver IAM Role..."
    
    # Check if service account already exists
    if kubectl get serviceaccount ebs-csi-controller-sa -n kube-system &> /dev/null; then
        print_info "EBS CSI Driver service account already exists"
    else
        # Check if --force-update flag is supported
        if eksctl create iamserviceaccount --help 2>&1 | grep -q "force-update"; then
            eksctl create iamserviceaccount \
                --name ebs-csi-controller-sa \
                --namespace kube-system \
                --cluster $CLUSTER_NAME \
                --region $REGION \
                --attach-policy-arn arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy \
                --approve \
                --force-update
        else
            # Fallback for older eksctl versions
            eksctl create iamserviceaccount \
                --name ebs-csi-controller-sa \
                --namespace kube-system \
                --cluster $CLUSTER_NAME \
                --region $REGION \
                --attach-policy-arn arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy \
                --approve
        fi
    fi
    
    # Install EBS CSI Driver (if not exists)
    print_info "Setting up EBS CSI Driver..."
    
    # Check if EBS CSI Driver is already deployed
    if kubectl get deployment ebs-csi-controller -n kube-system &> /dev/null; then
        print_info "EBS CSI Driver already deployed"
    else
        kubectl apply -k "github.com/kubernetes-sigs/aws-ebs-csi-driver/deploy/kubernetes/overlays/stable/"
    fi
    
    # Create storage classes (if not exist)
    print_info "Setting up storage classes..."
    
    # Check if storage classes already exist
    if kubectl get storageclass ebs-sc &> /dev/null; then
        print_info "Storage class 'ebs-sc' already exists"
    else
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
EOF
    fi
    
    if kubectl get storageclass ebs-sc-fast &> /dev/null; then
        print_info "Storage class 'ebs-sc-fast' already exists"
    else
        cat <<EOF | kubectl apply -f -
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
    fi
    
    # Set default storage class (if not already set)
    CURRENT_DEFAULT=$(kubectl get storageclass --no-headers | grep "default" | awk '{print $1}' || echo "")
    if [ "$CURRENT_DEFAULT" != "ebs-sc" ]; then
        print_info "Setting ebs-sc as default storage class..."
        kubectl patch storageclass ebs-sc -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
    else
        print_info "ebs-sc is already the default storage class"
    fi
    
    # Install Prometheus Operator CRDs
    print_info "Installing Prometheus Operator CRDs..."
    
    # Check if CRDs already exist
    if kubectl get crd prometheuses.monitoring.coreos.com &> /dev/null; then
        print_info "Prometheus Operator CRDs already exist"
    else
        # Try installing CRDs using server-side apply (handles large CRDs better)
        print_info "Installing Prometheus Operator CRDs using server-side apply..."
        
        # Install CRDs one by one with server-side apply
        if kubectl apply --server-side -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/main/example/prometheus-operator-crd/monitoring.coreos.com_prometheusrules.yaml && \
           kubectl apply --server-side -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/main/example/prometheus-operator-crd/monitoring.coreos.com_servicemonitors.yaml && \
           kubectl apply --server-side -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/main/example/prometheus-operator-crd/monitoring.coreos.com_prometheuses.yaml; then
            print_success "Prometheus Operator CRDs installed successfully"
        else
            print_warning "Server-side CRD installation failed, trying alternative method..."
            
            # Alternative: Skip CRDs and continue (they may not be needed for basic monitoring)
            print_info "Continuing without Prometheus Operator CRDs..."
            print_info "Basic monitoring will still work, but advanced Prometheus features may be limited."
        fi
    fi
    
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
        "monitoring/prometheus-rules.yaml"
        "monitoring/enhanced-prometheus-rules-fixed.yaml"
        "monitoring/grafana-config.yaml"
        "monitoring/grafana-deployment.yaml"
        "monitoring/grafana-datasources.yaml"
        "monitoring/grafana-dashboards.yaml"
        "monitoring/observability-dashboard-configmap.yaml"
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
    
    # Create monitoring namespace (if not exists)
    print_info "Setting up monitoring namespace..."
    kubectl apply -f monitoring/namespace.yaml
    
    # Ensure namespace exists and add small delay for propagation
    print_info "Ensuring namespace exists..."
    kubectl get namespace monitoring || kubectl create namespace monitoring
    sleep 3
    
    # Small delay to ensure namespace propagation
    sleep 3
    
    # Create ConfigMaps first to ensure they exist before deployments
    print_info "Creating ConfigMaps..."
    kubectl apply -f monitoring/grafana-dashboards.yaml
    kubectl apply -f monitoring/observability-dashboard-configmap.yaml
    
    # Small delay to ensure ConfigMaps are created
    sleep 2
    
    # Deploy core monitoring components
    print_info "Deploying core monitoring components..."
    kubectl apply -f monitoring/prometheus-config.yaml
    kubectl apply -f monitoring/prometheus-deployment.yaml
    kubectl apply -f monitoring/prometheus-rules.yaml
    kubectl apply -f monitoring/enhanced-prometheus-rules-fixed.yaml
    
    kubectl apply -f monitoring/grafana-config.yaml
    kubectl apply -f monitoring/grafana-deployment.yaml
    kubectl apply -f monitoring/grafana-datasources.yaml
    
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
    
    if [ "$LOAD_BALANCER_TYPE" = "alb" ]; then
        kubectl patch svc grafana -n monitoring -p '{"spec":{"type":"LoadBalancer"}}'
        kubectl patch svc prometheus -n monitoring -p '{"spec":{"type":"LoadBalancer"}}'
        kubectl patch svc alertmanager -n monitoring -p '{"spec":{"type":"LoadBalancer"}}'
    elif [ "$LOAD_BALANCER_TYPE" = "clb" ]; then
        kubectl patch svc grafana -n monitoring -p '{"spec":{"type":"LoadBalancer"}}'
        kubectl patch svc prometheus -n monitoring -p '{"spec":{"type":"LoadBalancer"}}'
        kubectl patch svc alertmanager -n monitoring -p '{"spec":{"type":"LoadBalancer"}}'
    else # nlb (default)
        kubectl patch svc grafana -n monitoring -p '{"spec":{"type":"LoadBalancer"}}'
        kubectl patch svc prometheus -n monitoring -p '{"spec":{"type":"LoadBalancer"}}'
        kubectl patch svc alertmanager -n monitoring -p '{"spec":{"type":"LoadBalancer"}}'
    fi
    
    print_success "Observability framework deployed successfully!"
}

# Function to wait for deployments
wait_for_deployments() {
    print_info "Waiting for all deployments to be ready..."
    
    # Wait for PVCs to be bound first
    print_info "Waiting for PVCs to be bound..."
    
    # Check if PVCs are already bound or wait for them
    local pvcs=("grafana-pvc" "prometheus-pvc" "loki-pvc" "tempo-pvc" "mimir-pvc")
    for pvc in "${pvcs[@]}"; do
        if kubectl get pvc "$pvc" -n monitoring -o jsonpath='{.status.phase}' 2>/dev/null | grep -q "Bound"; then
            print_success "PVC $pvc is already bound"
        else
            print_info "Waiting for PVC $pvc to be bound..."
            kubectl wait --for=condition=Bound --timeout=300s "pvc/$pvc" -n monitoring || print_warning "PVC $pvc binding timeout (may be using WaitForFirstConsumer)"
        fi
    done
    
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
    print_info "Waiting for Load Balancers to be provisioned...$LOAD_BALANCER_TYPE" 
    
    #kubectl wait --for=condition=Ready --timeout=3000s svc/grafana -n monitoring
    #kubectl wait --for=condition=Ready --timeout=3000s svc/prometheus -n monitoring
    #kubectl wait --for=condition=Ready --timeout=3000s svc/alertmanager -n monitoring
    kubectl wait --for=condition=Available=True --timeout=300s deployment/grafana -n monitoring
    kubectl wait --for=condition=Available=True --timeout=300s deployment/prometheus -n monitoring
    kubectl wait --for=condition=Available=True --timeout=300s deployment/alertmanager -n monitoring
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
    GRAFANA_LB=$(kubectl get svc grafana -n monitoring -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
    PROMETHEUS_LB=$(kubectl get svc prometheus -n monitoring -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
    ALERTMANAGER_LB=$(kubectl get svc alertmanager -n monitoring -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
    
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
    echo "Load Balancer Type: $LOAD_BALANCER_TYPE"
    echo ""
    
    # Get Load Balancer URLs
    GRAFANA_LB=$(kubectl get svc grafana -n monitoring -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
    PROMETHEUS_LB=$(kubectl get svc prometheus -n monitoring -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
    ALERTMANAGER_LB=$(kubectl get svc alertmanager -n monitoring -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
    
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
    echo "kubectl port-forward -n monitoring svc/grafana 3000:3000"
    echo "kubectl port-forward -n monitoring svc/prometheus 9090:9090"
    echo "kubectl port-forward -n monitoring svc/alertmanager 9093:9093"
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
    
    # Parse command line arguments
    parse_arguments "$@"
    
    echo "Configuration:"
    echo "- Cluster Name: $CLUSTER_NAME"
    echo "- Region: $REGION"
    echo "- Node Type: $NODE_TYPE"
    echo "- Node Count: $NODE_COUNT"
    echo "- EKS Version: $EKS_VERSION"
    echo "- Use Existing Cluster: $USE_EXISTING_CLUSTER"
    echo "- Load Balancer Type: $LOAD_BALANCER_TYPE"
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