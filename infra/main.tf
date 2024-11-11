provider "aws" {
  region = "us-east-1"
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "main-igw"
  }
}

resource "aws_route_table" "main" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "main-route-table"
  }
}

resource "aws_route_table_association" "subnet_a" {
  subnet_id      = aws_subnet.subnet_a.id
  route_table_id = aws_route_table.main.id
}

resource "aws_route_table_association" "subnet_b" {
  subnet_id      = aws_subnet.subnet_b.id
  route_table_id = aws_route_table.main.id
}


resource "aws_security_group" "nginx_sg" {
  name_prefix = "nginx-sg"
  vpc_id     = aws_vpc.main.id

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



resource "aws_launch_template" "nginx_launch_template" {
  name_prefix   = "nginx-launch-template"
  image_id      = "ami-0dba2cb6798deb6d8"  # Ubuntu 20.04 LTS
  instance_type = "t2.micro"
 # key_name      = aws_key_pair.key.key_name

  # Load the user data script from an external file
  user_data = filebase64("nginx_setup.sh")

  network_interfaces {
    security_groups = [aws_security_group.nginx_sg.id]
    associate_public_ip_address = true
  }

  # Tag instances created by this launch template
  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "Nginx-Auto-Scaled-Instance"
    }
  }
}

# Auto Scaling Group
resource "aws_autoscaling_group" "nginx_asg" {
  launch_template {
    id      = aws_launch_template.nginx_launch_template.id
    version = "$Latest"
  }

  min_size             = 1
  max_size             = 5
  desired_capacity     = 2
  vpc_zone_identifier  = [aws_subnet.subnet_a.id, aws_subnet.subnet_b.id]
  health_check_type    = "EC2"
  health_check_grace_period = 300

  # Tag instances created by the Auto Scaling Group
  tag {
    key                 = "Name"
    value               = "Nginx-Auto-Scaled"
    propagate_at_launch = true
  }

  # Attach Scaling Policies (next section)
  depends_on = [aws_launch_template.nginx_launch_template]
}

# CloudWatch Metric Alarm for CPU Utilization
resource "aws_cloudwatch_metric_alarm" "cpu_alarm_high" {
  alarm_name                = "cpu_high"
  comparison_operator       = "GreaterThanOrEqualToThreshold"
  evaluation_periods        = 2
  metric_name               = "CPUUtilization"
  namespace                 = "AWS/EC2"
  period                    = 60 
  statistic                 = "Average"
  threshold                 = 70
  alarm_description         = "This metric monitors high CPU utilization"
  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.nginx_asg.name
  }

  # Trigger scaling policy when alarm is breached
  alarm_actions = [aws_autoscaling_policy.scale_out_policy.arn]
}

resource "aws_cloudwatch_metric_alarm" "cpu_alarm_low" {
  alarm_name                = "cpu_low"
  comparison_operator       = "LessThanOrEqualToThreshold"
  evaluation_periods        = 2
  metric_name               = "CPUUtilization"
  namespace                 = "AWS/EC2"
  period                    = 60 
  statistic                 = "Average"
  threshold                 = 20
  alarm_description         = "This metric monitors low CPU utilization"
  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.nginx_asg.name
  }

  # Trigger scaling policy when alarm is breached
  alarm_actions = [aws_autoscaling_policy.scale_in_policy.arn]
}

# Auto Scaling Policy - Scale Out
resource "aws_autoscaling_policy" "scale_out_policy" {
  name                   = "scale_out"
  scaling_adjustment     = 1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 30
  autoscaling_group_name = aws_autoscaling_group.nginx_asg.name
}

# Auto Scaling Policy - Scale In
resource "aws_autoscaling_policy" "scale_in_policy" {
  name                   = "scale_in"
  scaling_adjustment     = -1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = aws_autoscaling_group.nginx_asg.name
}

resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "main-vpc"
  }
}

resource "aws_subnet" "subnet_a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "subnet-a"
  }
}

resource "aws_subnet" "subnet_b" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "us-east-1b"

  tags = {
    Name = "subnet-b"
  }
}

##ALB
resource "aws_autoscaling_attachment" "asg_attachment" {
  autoscaling_group_name = aws_autoscaling_group.nginx_asg.name
  lb_target_group_arn   = aws_lb_target_group.nginx_tg.arn
}

resource "aws_lb" "nginx_alb" {
  name               = "nginx-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.nginx_sg.id]
  subnets            = [aws_subnet.subnet_a.id, aws_subnet.subnet_b.id]

  enable_deletion_protection = false 

  tags = {
    Name = "nginx-alb"
  }
}

resource "aws_lb_target_group" "nginx_tg" {
  name     = "nginx-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  health_check {
    interval            = 30
    path                = "/"
    timeout             = 5
    healthy_threshold   = 5
    unhealthy_threshold = 2
    matcher             = "200"
  }

  tags = {
    Name = "nginx-tg"
  }
}


resource "aws_lb_listener" "nginx_listener" {
  load_balancer_arn = aws_lb.nginx_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.nginx_tg.arn
  }
}

resource "aws_lb_target_group" "nginx_tg_https" {
  name     = "nginx-tg-https"
  port     = 443
  protocol = "HTTPS"
  vpc_id   = aws_vpc.main.id

  health_check {
    interval            = 30
    path                = "/"
    timeout             = 5
    healthy_threshold   = 5
    unhealthy_threshold = 2
    matcher             = "200"
  }

  tags = {
    Name = "nginx-tg-https"
  }
}

resource "aws_lb_listener" "https_listener" {
  load_balancer_arn = aws_lb.nginx_alb.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = "arn:aws:acm:us-east-1:724772066377:certificate/f02e89ed-c4c0-4c4d-bbb3-38af7d93bb2d"  # Reference the certificate ARN

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.nginx_tg_https.arn
  }
}



### Public IPs
# locals {
#   instance_ids = flatten([
#     for instance in aws_autoscaling_group.nginx_asg.instances : instance.id
#   ])
# }

# data "aws_instance" "nginx_instances" {
#   count = length(local.instance_ids)
#   instance_id = local.instance_ids[count.index]
# }

# output "nginx_asg_public_ips" {
#   description = "The public IP addresses of the Nginx Auto Scaling Group instances"
#   value       = [for instance in data.aws_instance.nginx_instances : instance.public_ip]
# }

output "alb_dns_name" {
  description = "The DNS name of the ALB"
  value       = aws_lb.nginx_alb.dns_name
}