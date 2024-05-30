variable "aws_access_key" {}
variable "aws_secret_key" {}

provider "aws" {
  region     = "ap-northeast-1"
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
}

#XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
#XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
# VPCのモジュール
#XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
#XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
module "vpc" {
  source = "./modules/vpc"
}


#XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
#XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
# Aurora RDSモジュール
#XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
#XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
resource "aws_db_subnet_group" "main" {
  name       = "db-subnet-group"
  subnet_ids = ["${module.vpc.private_subnet_ids[0]}", "${module.vpc.private_subnet_ids[1]}"]
  tags = {
    Name = "DB Subnet Group"
  }
}

resource "aws_security_group" "my_db_security_group" {
  vpc_id = module.vpc.vpc_id

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_rds_cluster" "my_db_cluster" {
  cluster_identifier      = "my-db-cluster"
  engine                  = "aurora-postgresql"
  master_username         = "testuser"
  master_password         = "password"
  db_subnet_group_name    = aws_db_subnet_group.main.name
  vpc_security_group_ids  = [aws_security_group.my_db_security_group.id]
  availability_zones      = ["ap-northeast-1a", "ap-northeast-1c"]
  preferred_backup_window = "07:00-09:00"
  backup_retention_period = 7
  skip_final_snapshot     = true
  apply_immediately       = true

  //lifecyleを指定しないとインスタンスタイプ変更するときに、作り直しになる。
  lifecycle {
    ignore_changes = [
      availability_zones,
    ]
  }
}

resource "aws_rds_cluster_instance" "aurora_instances" {
  count                      = 2
  cluster_identifier         = aws_rds_cluster.my_db_cluster.id
  instance_class             = "db.t3.medium"
  engine                     = "aurora-postgresql"
  engine_version             = "15.4"
  identifier                 = "aurora-instance-${count.index}"
  publicly_accessible        = false
  auto_minor_version_upgrade = true
  apply_immediately          = true
}


output "aurora_endpoint" {
  value     = aws_rds_cluster.my_db_cluster.endpoint
  sensitive = true
}

output "aurora_port" {
  value     = aws_rds_cluster.my_db_cluster.port
  sensitive = true
}

output "aurora_username" {
  value     = aws_rds_cluster.my_db_cluster.master_username
  sensitive = true
}

output "aurora_password" {
  value     = aws_rds_cluster.my_db_cluster.master_password
  sensitive = true
}
