# 1. Conexión con AWS
provider "aws" {
  region = "us-east-1"
}

# 2. Conector para tu rol de IAM existente
resource "aws_iam_instance_profile" "mi_perfil" {
  name = "EC2-ml-profile"
  role = "EC2-ml"
}

# 3. Security Group para permitir entrada SSH (puerto 22) y salida a todo internet
resource "aws_security_group" "sg_ssh" {
  name = "permitir-ssh-mlflow"
  description = "Permitir entrada SSH, MLflow y salida HTTPS"
  ingress = {
    description = "SSH"
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress = {
    description = "MLflow"
    from_port = 5000
    to_port = 5000
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress = {
    description = "HTTPS"
    from_port = 443
    to_port = 443
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "sg-permitir-ssh-mlflow"
  }
}
# 4. Creación de la máquina EC2
resource "aws_instance" "servidor_mlflow" {
  ami                  = "ami-0c7217cdde317cfec"
  instance_type        = "t3.medium"
  iam_instance_profile = aws_iam_instance_profile.mi_perfil.name
  key_name             = "Amazon"

  # Asociación del Security Group
  vpc_security_group_ids = [aws_security_group.sg_ssh.id]

  # Configuración del disco duro EBS
  root_block_device {
    volume_size           = 8
    volume_type           = "gp3"
    delete_on_termination = true
  }

  tags = {
    Name = "servidor-mlflow"
  }
}