#!/bin/bash

set -e

NOME="DiegoHenrique"

GRUPO_SEGURANCA="${NOME}-grupo"
NOME_INSTANCIA="instancia-${NOME}"
PAR_CHAVE="parchave-${NOME}"

echo "LAB EC2 - ESCOLA DA NUVEM"

VPC_ID=$(aws ec2 describe-vpcs \
  --filters Name=isDefault,Values=true \
  --query "Vpcs[0].VpcId" \
  --output text)

if ! aws ec2 describe-key-pairs \
  --key-names "$PAR_CHAVE" >/dev/null 2>&1; then

  aws ec2 create-key-pair \
    --key-name "$PAR_CHAVE" \
    --query 'KeyMaterial' \
    --output text > "${PAR_CHAVE}.pem"

  chmod 400 "${PAR_CHAVE}.pem
fi

SECURITY_GROUP_ID=$(aws ec2 describe-security-groups \
  --filters \
  Name=group-name,Values="$GRUPO_SEGURANCA" \
  Name=vpc-id,Values="$VPC_ID" \
  --query "SecurityGroups[0].GroupId" \
  --output text)

if [[ "$SECURITY_GROUP_ID" == "None" ]]; then
  SECURITY_GROUP_ID=$(aws ec2 create-security-group \
    --group-name "$GRUPO_SEGURANCA" \
    --description "Permitir HTTP" \
    --vpc-id "$VPC_ID" \
    --query "GroupId" \
    --output text)

  aws ec2 authorize-security-group-ingress \
    --group-id "$SECURITY_GROUP_ID" \
    --protocol tcp \
    --port 80 \
    --cidr 0.0.0.0/0
fi

AMI_ID=$(aws ssm get-parameter \
  --name /aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64 \
  --query 'Parameter.Value' \
  --output text)

INSTANCE_ID=$(aws ec2 run-instances \
  --image-id "$AMI_ID" \
  --instance-type t2.micro \
  --security-group-ids "$SECURITY_GROUP_ID" \
  --key-name "$PAR_CHAVE" \
  --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$NOME_INSTANCIA}]" \
  --user-data '#!/bin/bash
dnf install -y httpd
systemctl enable --now httpd
echo "<html><h1>Olá do seu servidor web!</h1></html>" > /var/www/html/index.html' \
  --query 'Instances[0].InstanceId' \
  --output text)

echo "Instância criada: $INSTANCE_ID"
