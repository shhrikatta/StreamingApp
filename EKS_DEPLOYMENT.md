# EKS Deployment Guide

## Prerequisites

- [AWS CLI v2](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html) configured with credentials
- [eksctl](https://eksctl.io/installation/)
- [kubectl](https://kubernetes.io/docs/tasks/tools/)
- [Helm 3](https://helm.sh/docs/intro/install/)
- [Docker](https://docs.docker.com/get-docker/)

## 1. Create the EKS Cluster

```bash
eksctl create cluster -f eks/cluster.yaml
```

This provisions a cluster named `streamingapp-cluster` in `us-east-1` with:
- 2–4 `t3.medium` nodes (managed node group)
- OIDC provider enabled (for IRSA)
- CloudWatch logging (api, audit, controllerManager)

Cluster creation takes ~15–20 minutes. Verify with:

```bash
kubectl get nodes
```

## 2. Install the AWS Load Balancer Controller

The Helm chart uses an ALB Ingress, which requires the AWS Load Balancer Controller.

```bash
# Create IAM policy
curl -o iam_policy.json https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.7.1/docs/install/iam_policy.json

aws iam create-policy \
  --policy-name AWSLoadBalancerControllerIAMPolicy \
  --policy-document file://iam_policy.json

# Create service account
eksctl create iamserviceaccount \
  --cluster=streamingapp-cluster \
  --namespace=kube-system \
  --name=aws-load-balancer-controller \
  --attach-policy-arn=arn:aws:iam::<AWS_ACCOUNT_ID>:policy/AWSLoadBalancerControllerIAMPolicy \
  --approve

# Install via Helm
helm repo add eks https://aws.github.io/eks-charts
helm repo update

helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=streamingapp-cluster \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller
```

## 3. Push Docker Images to ECR

Create ECR repositories and push images:

```bash
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
AWS_REGION=us-east-1

# Login to ECR
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com

# Create repositories
for svc in auth streaming admin chat frontend; do
  aws ecr create-repository --repository-name streamingapp-$svc --region $AWS_REGION 2>/dev/null
done

# Build and push auth service
docker build -t streamingapp-auth ./backend/authService
docker tag streamingapp-auth:latest $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/streamingapp-auth:latest
docker push $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/streamingapp-auth:latest

# Build and push streaming service
docker build -t streamingapp-streaming -f backend/streamingService/Dockerfile ./backend
docker tag streamingapp-streaming:latest $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/streamingapp-streaming:latest
docker push $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/streamingapp-streaming:latest

# Build and push admin service
docker build -t streamingapp-admin -f backend/adminService/Dockerfile ./backend
docker tag streamingapp-admin:latest $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/streamingapp-admin:latest
docker push $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/streamingapp-admin:latest

# Build and push chat service
docker build -t streamingapp-chat -f backend/chatService/Dockerfile ./backend
docker tag streamingapp-chat:latest $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/streamingapp-chat:latest
docker push $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/streamingapp-chat:latest

# Build and push frontend (set API URLs to your ALB hostname after it's provisioned)
docker build -t streamingapp-frontend \
  --build-arg REACT_APP_AUTH_API_URL=http://<ALB_HOSTNAME>/api \
  --build-arg REACT_APP_STREAMING_API_URL=http://<ALB_HOSTNAME>/api \
  --build-arg REACT_APP_STREAMING_PUBLIC_URL=http://<ALB_HOSTNAME> \
  --build-arg REACT_APP_ADMIN_API_URL=http://<ALB_HOSTNAME>/api/admin \
  --build-arg REACT_APP_CHAT_API_URL=http://<ALB_HOSTNAME>/api/chat \
  --build-arg REACT_APP_CHAT_SOCKET_URL=http://<ALB_HOSTNAME> \
  ./frontend
docker tag streamingapp-frontend:latest $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/streamingapp-frontend:latest
docker push $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/streamingapp-frontend:latest
```

## 4. Deploy with Helm

Create a `values-override.yaml` with your actual values:

```yaml
secrets:
  jwtSecret: "your-strong-jwt-secret"
  awsAccessKeyId: "AKIA..."
  awsSecretAccessKey: "your-secret-key"

config:
  clientUrls: "http://<ALB_HOSTNAME>"
  awsS3Bucket: "your-bucket-name"
  awsCdnUrl: "https://your-cdn.cloudfront.net"

auth:
  image:
    repository: <AWS_ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com/streamingapp-auth

streaming:
  image:
    repository: <AWS_ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com/streamingapp-streaming
  streamingPublicUrl: "http://<ALB_HOSTNAME>"

admin:
  image:
    repository: <AWS_ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com/streamingapp-admin

chat:
  image:
    repository: <AWS_ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com/streamingapp-chat

frontend:
  image:
    repository: <AWS_ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com/streamingapp-frontend
```

Install the chart:

```bash
helm install streamingapp ./helm/streamingapp -f values-override.yaml
```

## 5. Verify Deployment

```bash
# Check all pods are running
kubectl get pods -n streamingapp

# Get the ALB hostname
kubectl get ingress -n streamingapp

# Test the frontend
curl http://<ALB_HOSTNAME>/
```

## Useful Commands

```bash
# Upgrade after changes
helm upgrade streamingapp ./helm/streamingapp -f values-override.yaml

# Uninstall
helm uninstall streamingapp

# Delete the EKS cluster
eksctl delete cluster -f eks/cluster.yaml --disable-nodegroup-eviction
```
