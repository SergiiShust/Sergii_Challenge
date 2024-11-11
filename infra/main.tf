provider "aws" {
  region = "us-east-1"
}

# resource "aws_key_pair" "key" {
#   key_name   = "nginx-key"
#   public_key = file("~/.ssh/id_rsa.pub")  # Replace with your actual public key path
# }

resource "aws_security_group" "nginx_sg" {
  name_prefix = "nginx-sg"

  # Allow SSH, HTTP (for redirection), and HTTPS
#   ingress {
#     from_port   = 22
#     to_port     = 22
#     protocol    = "tcp"
#     cidr_blocks = ["0.0.0.0/0"]
#   }
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 443
    to_port     = 443
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

resource "aws_instance" "nginx_ec2" {
  ami           = "ami-0dba2cb6798deb6d8"  # Ubuntu 20.04 LTS in us-east-1
  instance_type = "t2.micro"
#   key_name      = aws_key_pair.key.key_name
  security_groups = [aws_security_group.nginx_sg.name]

  # Cloud-init script to configure Nginx and HTTPS
  user_data = file("nginx_setup.sh")

  tags = {
    Name = "Nginx-Web-Server"
  }
}


output "nginx_ec2_public_ip" {
  description = "The public IP address of the Nginx EC2 instance"
  value       = aws_instance.nginx_ec2.public_ip
}
