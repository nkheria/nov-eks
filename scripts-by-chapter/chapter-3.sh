./scripts-by-chapter/chapter-1.sh
./scripts-by-chapter/chapter-2.sh

echo "***************************************************"
echo "********* CHAPTER 3 - STARTED AT $(date) **********"
echo "***************************************************"

# Create OIDC Provider and connect it with EKS
    eksctl utils associate-iam-oidc-provider --cluster=eks-acg --approve

# Create IAM Policies of Bookstore Microservices
    ( cd clients-api/infra/cloudformation && ./create-iam-policy.sh )
    ( cd resource-api/infra/cloudformation && ./create-iam-policy.sh )
    ( cd inventory-api/infra/cloudformation && ./create-iam-policy.sh )
    ( cd renting-api/infra/cloudformation && ./create-iam-policy.sh )

# Getting NodeGroup IAM Role from Kubernetes Cluster
    nodegroup_iam_role=$(aws cloudformation list-exports --query "Exports[?contains(Name, 'nodegroup-eks-node-group::InstanceRoleARN')].Value" --output text | xargs | cut -d "/" -f 2)

# Removing DynamoDB Permissions to the node
    aws iam detach-role-policy --role-name ${nodegroup_iam_role} --policy-arn arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess

# Create IAM Service Accounts
    resource_iam_policy=$(aws cloudformation describe-stacks --stack development-iam-policy-resource-api --query "Stacks[0].Outputs[0]" | jq .OutputValue | tr -d '"')
    renting_iam_policy=$(aws cloudformation describe-stacks --stack development-iam-policy-renting-api --query "Stacks[0].Outputs[0]" | jq .OutputValue | tr -d '"')
    inventory_iam_policy=$(aws cloudformation describe-stacks --stack development-iam-policy-inventory-api --query "Stacks[0].Outputs[0]" | jq .OutputValue | tr -d '"')
    clients_iam_policy=$(aws cloudformation describe-stacks --stack development-iam-policy-clients-api --query "Stacks[0].Outputs[0]" | jq .OutputValue | tr -d '"')
    eksctl create iamserviceaccount --name resources-api-iam-service-account \
        --namespace development \
        --cluster eks-acg \
        --attach-policy-arn ${resource_iam_policy} --approve
    eksctl create iamserviceaccount --name renting-api-iam-service-account \
        --namespace development \
        --cluster eks-acg \
        --attach-policy-arn ${renting_iam_policy} --approve
    eksctl create iamserviceaccount --name inventory-api-iam-service-account \
        --namespace development \
        --cluster eks-acg \
        --attach-policy-arn ${inventory_iam_policy} --approve
    eksctl create iamserviceaccount --name clients-api-iam-service-account \
        --namespace development \
        --cluster eks-acg \
        --attach-policy-arn ${clients_iam_policy} --approve

# Upgrading the applications
    ( cd ./resource-api/infra/helm-v2 && ./create.sh )
    ( cd ./clients-api/infra/helm-v2 && ./create.sh )
    ( cd ./inventory-api/infra/helm-v2 && ./create.sh )
    ( cd ./renting-api/infra/helm-v2 && ./create.sh )


# Updating IRSA for AWS Load Balancer Controller
    
    helm del -n kube-system aws-load-balancer-controller # Uninstall first
    ( cd ./Infrastructure/k8s-tooling/load-balancer-controller && ./create-irsa.sh )


echo "*************************************************************"
echo "********* READY FOR CHAPTER 4 - FINISHED AT $(date) *********"
echo "*************************************************************"