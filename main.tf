provider "aws" {
  region = "us-east-2"
}

variable "A_project_name" {
  description = "Nome Identificador do  Cliente"
  type        = string
}

resource "aws_instance" "MINIKUBE" {
  ami           = "ami-0229f9a2f1b77bc37"
  key_name = "Keys_DockerServerFastDeliveryAWS"
  vpc_security_group_ids = ["${aws_security_group.MINIKUBE.id}"]
  associate_public_ip_address = true
  instance_type = "t2.large"
  tags = {
    Name = var.A_project_name
  }
  user_data = <<-EOF
        #!/bin/bash
        apt-get install git -y
        git clone https://github.com/corcelli/minikube-github-cicd.git
        cd minikube-github-cicd
        chmod +x install_docker_debian.sh
        ./install_docker_debian.sh
        EOF
}

resource "aws_eip" "MINIKUBE" {
  instance = aws_instance.MINIKUBE.id
  vpc      = true

  
  tags = {
    Name = "eip-${var.A_project_name}"
  }

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_eip_association" "MINIKUBE" {
  instance_id   = aws_instance.MINIKUBE.id
  allocation_id = aws_eip.MINIKUBE.id
}


data "template_file" "user_data" {
  template = "${file("script.sh")}"
}

resource "aws_security_group" "MINIKUBE" {
  name = var.A_project_name
  description = var.A_project_name
  ingress {
    from_port   = 9000
    to_port     = 9000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 3334
    to_port     = 3334
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 5000
    to_port     = 5000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 81
    to_port     = 81
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
    ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

}

#####DNS Route53 ####

resource "aws_route53_record" "MINIKUBE" {
  zone_id = "Z02536331TX68R0C60A2M"
  name    = var.B_project_DNS
  type    = "CNAME"
  ttl     = "300"
  #records = [aws_eip.lb.public_ip]
  records = [aws_lb.MINIKUBE.dns_name]
}


  /* resource "aws_db_instance" "MINIKUBE" {
    name = var.A_rds_name
    allocated_storage    = 50
    availability_zone = "us-east-2b"
    vpc_security_group_ids    = ["${aws_security_group.MINIKUBE.id}"]
    engine               = "postgres"
    engine_version       = "13.2"
    instance_class       = "db.m5.large"
    password             = var.C_RDS_pass
    skip_final_snapshot  = true
    storage_encrypted    = true
    username             = "postgres"
    publicly_accessible = true
    tags = {
  Name       = var.A_rds_name
  Environment = "Producao"
    }


  } */


#####LoadBalacing + SSL Certified ####
resource "aws_lb" "MINIKUBE" {
  name            = var.A_project_name
  internal           = false
  load_balancer_type = "application"
  subnets 	= ["subnet-a50f62e9", "subnet-74c7fd0e"]
  #subnets = ["${aws_subnet.MINIKUBE.*.id}"]
  security_groups = ["${aws_security_group.MINIKUBE.id}"]
  tags = {
    Environment = "production"
  }

}
#resource "aws_lb_listener" "MINIKUBE" {
#  load_balancer_arn = "${aws_lb.MINIKUBE.arn}"
#  port              = "80"
#  protocol          = "HTTP"
#  default_action {
#    type             = "forward"
#    target_group_arn = "${aws_lb_target_group.MINIKUBE.arn}"
#  }
#}

resource "aws_lb_listener" "MINIKUBE_front_end" {
  load_balancer_arn = "${aws_lb.MINIKUBE.arn}"
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

resource "aws_alb_listener" "MINIKUBE" {
  load_balancer_arn = "${aws_lb.MINIKUBE.arn}"
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn = "arn:aws:acm:us-east-2:592097629406:certificate/c75fe7cf-d099-4a19-b483-0810534b747b"
  default_action {
    target_group_arn = "${aws_lb_target_group.MINIKUBE.arn}"
    type             = "forward"
  }
}
#resource "aws_lb_listener_certificate" "MINIKUBE" {
#  listener_arn    = "${aws_alb_listener.MINIKUBE.arn}"
#  certificate_arn = "arn:aws:acm:us-east-2:592097629406:certificate/24bdf836-49b9-499f-aba6-560e44f18026"
#}


resource "aws_lb_target_group" "MINIKUBE" {
  name     = var.A_project_name
  port     = 80
  protocol = "HTTP"
  #vpc_id   = "${aws_vpc.MINIKUBE.id}"
  vpc_id = "vpc-f2b41099"
  stickiness {
    type = "lb_cookie"
  }
  # Alter the destination of the health check to be the login page.
  health_check {
    path = "/"
    port = 80
  }
}


resource "aws_lb_target_group_attachment" "MINIKUBE" {
  target_group_arn = aws_lb_target_group.MINIKUBE.arn
  target_id        = aws_instance.MINIKUBE.id
  port             = 3334
}


#resource "aws_vpc" "MINIKUBE" {
#  cidr_block = "172.31.0.0/16"
#}



output "public_ip_EC2" {
  value       = aws_instance.MINIKUBE.public_ip
  description = "The public IP EC2 server"
}

output "public_RDS_endpoint" {
  value       = aws_db_instance.MINIKUBE.endpoint
  description = "RDS endpoint Access"
}

output "public_RDS_Nome_Banco_Dados" {
  value       = aws_db_instance.MINIKUBE.name
  description = "Nome do banco de dados:"
}
#output "public_DNS_LB" {
#  value       = aws_lb.MINIKUBE.dns_name
#  description = "The public LB DNS"
#}

output "project_DNS" {
  value       = "https://${var.B_project_DNS}"
  description = "DNS de acesso final"
}

output "Portainer" {
  value       = "https://${var.B_project_DNS}:9000"
  description = "DNS de acesso final"
}

