# 1. Conexión con AWS
provider "aws" {
  region = "us-east-1"
}
# Declaración de la variable para la contraseña (vinculada al terraform.tfvars)
variable "db_password" {
  type        = string
  description = "Contrasena de la base de datos RDS"
  sensitive   = true
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
  ingress {
    description = "SSH"
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "MLflow"
    from_port = 5000
    to_port = 5000
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    description = "HTTPS"
    from_port = 443
    to_port = 443
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    description = "POSTGRES RDS TCP"
    from_port = 5432
    to_port = 5432
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "sg-permitir-ssh-mlflow"
  }
}
# 4. Security Group exclusivo para la Base de datos RDS
resource "aws_security_group" "sg_rds" {
  name = "permitir-rds-mlflow"
  description = "Permitir entrada RDS a la instancia EC2"
  #  Permite la conexion con el EC2
  ingress {
    description = "Postgres desde EC2"
    from_port = 5432
    to_port = 5432
    protocol = "tcp"
    security_groups = [aws_security_group.sg_ssh.id]
  }
  # Permite la conexion con todo el internet
  egress {
    from_port = 0
    to_port = 0
    protocol = "-1" # Todos los protocolos
    cidr_blocks = ["0.0.0.0/0"]
  }  
  tags = {
    Name = "sg-postgres-rds"
  }
}
# 5 Obtenercion de una VPC por defecto y sus subredes
## Buscar la VPC por defecto
data "aws_vpc" "default" {
  default = true
}
## Obtener la lista de subredes
data "aws_subnets" "default" {
  filter {
    name = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}
## Crear un grupo de subredes
resource "aws_db_subnet_group" "rds_subnet_group" {
  name = "db-subnet-group-mlflow"
  subnet_ids = data.aws_subnets.default.ids
  tags = {
    Name = "MLflow DB Subnet Group"
  }
}
# 6. Creación de la máquina EC2
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
# 7. Bucket de S3 para almacenar artefactos
resource "aws_s3_bucket" "mlflow_artifacts" {
  bucket = "mlflow-artifacts-jhairo"
  force_destroy = true
  tags = {
    Name = "mlflow-artifacts"
    environment = "mlflow"
  }
}
output "s3_bucket_uri" {
  description = "URI del bucket de S3"
  value = "s3://${aws_s3_bucket.mlflow_artifacts.id}"
}
resource "aws_db_instance" "postgres_mlflow"{
  identifier             = "mlflow-db"
  engine                 = "postgres"
  engine_version         = "18.3"
  instance_class         = "db.t3.micro"
  allocated_storage      = 20
  db_name                = "mlflow"
  username               = "mlflow_user"
  password               = var.db_password
  db_subnet_group_name   = aws_db_subnet_group.rds_subnet_group.name
  vpc_security_group_ids = [aws_security_group.sg_rds.id]
  skip_final_snapshot    = true
  tags = {
    Name = "postgres-mlflow"
  }
}
