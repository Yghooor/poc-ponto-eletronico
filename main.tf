# main.tf

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.0"
    }
  }
}

provider "aws" {
  region = "us-east-1" # Você pode alterar para a região do projeto
}

# ==========================================
# 1. GESTÃO DE KEY PAIR SSH
# ==========================================

# Gera a chave privada localmente
resource "tls_private_key" "poc_key" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

# Envia a chave pública para a AWS
resource "aws_key_pair" "ec2_key" {
  key_name   = "ponto-eletronico-key"
  public_key = tls_private_key.poc_key.public_key_openssh
}

# Salva a chave privada na sua máquina com a permissão correta (0400)
# Isso será fundamental para a task CLD-105
resource "local_file" "private_key" {
  content         = tls_private_key.poc_key.private_key_pem
  filename        = "${path.module}/ponto-eletronico-key.pem"
  file_permission = "0400"
}

# ==========================================
# 2. GOVERNANÇA IAM (LEAST PRIVILEGE)
# ==========================================

# Cria o usuário IAM
resource "aws_iam_user" "dev_user" {
  name = "yghor.dev"
}

# Cria um grupo lógico para gerenciar permissões
resource "aws_iam_group" "ec2_readers" {
  name = "EC2_Readers_PoC"
}

# Anexa uma política de Menor Privilégio ao grupo
# Neste exemplo, o usuário só pode listar as EC2, sem permissão de criar ou destruir recursos.
resource "aws_iam_group_policy" "ec2_least_privilege" {
  name  = "ec2-read-only-policy"
  group = aws_iam_group.ec2_readers.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "ec2:DescribeInstances",
          "ec2:DescribeTags",
          "ec2:DescribeVolumes",
          "ec2:DescribeKeyPairs"
        ]
        Effect   = "Allow"
        Resource = "*"
      },
    ]
  })
}

# Vincula o usuário ao grupo
resource "aws_iam_user_group_membership" "add_user_to_group" {
  user = aws_iam_user.dev_user.name
  groups = [
    aws_iam_group.ec2_readers.name
  ]
}