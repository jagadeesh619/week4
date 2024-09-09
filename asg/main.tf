resource "aws_security_group" "allow_ssh_https" {
  name        = "alb-sg"
  description = "alb-sg"
  vpc_id      = "vpc-09d7d48442f764b5d"

  tags = {
    Name = "alb-sg"
  }
}

# Allow HTTPS traffic
resource "aws_security_group_rule" "allow_https" {
  type              = "ingress"
  security_group_id = aws_security_group.allow_ssh_https.id
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
}


resource "aws_security_group_rule" "allow_all_traffic_ipv4" {
  type              = "egress"
  security_group_id = aws_security_group.allow_ssh_https.id
  from_port         = 0
  to_port           = 0
  protocol          = "-1" # Semantically equivalent to all protocols
  cidr_blocks       = ["0.0.0.0/0"]
}


resource "aws_lb" "app_alb" {
  name               = "week-4-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.allow_ssh_https.id]
  subnets            = ["subnet-01ceef28efa3e7266","subnet-097da121f5c075b9a"]

  tags = {
    Name = "week4-alb"
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.app_alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.week4.arn
  }
}


resource "aws_lb_target_group" "week4" {
  name     = "week4-alb-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = "vpc-09d7d48442f764b5d"
  deregistration_delay = 60
  health_check {
      healthy_threshold   = 2
      interval            = 10
      unhealthy_threshold = 3
      timeout             = 5
      path                = "/health"
      port                = 80
      matcher = "200-299"      
  }
}


resource "aws_launch_template" "week4" {
  name = "week4-launch-template"

 
  image_id = "ami-0250ca08a6e69786b"

  instance_initiated_shutdown_behavior = "terminate"

  
  instance_type = "t2.micro"
  
  vpc_security_group_ids = [aws_security_group.allow_ssh_https.id]

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "week4-launch-template"
    }
  }
}

resource "aws_autoscaling_group" "week4" {
  name     = "week4-ASG"
  max_size                  = 5
  min_size                  = 1
  health_check_grace_period = 60
  health_check_type         = "ELB"
  desired_capacity          = 1
  vpc_zone_identifier       = ["subnet-01ceef28efa3e7266","subnet-097da121f5c075b9a"]
  target_group_arns = [aws_lb_target_group.week4.arn]
  launch_template {
    id      = aws_launch_template.week4.id
  }
  instance_refresh {
    strategy = "Rolling"
    preferences {

      min_healthy_percentage = 50
    }
    triggers = ["launch_template"]
  }

  tag {
    key                 = "Name"
    value               = "week4-ASG"
    propagate_at_launch = true
  }

  timeouts {
    delete = "15m"
  }

 
}


#resource "aws_lb_listener_rule" "static" {
 # listener_arn = aws_lb_listener.http.arn
  #priority     = 10

  #action {
   # type             = "forward"
    #target_group_arn = aws_lb_target_group.week4.arn
  #}
#}


resource "aws_autoscaling_policy" "week4" {
  autoscaling_group_name = aws_autoscaling_group.week4.name
  name                   = "week4-asg-policy"
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }

    target_value = 10.0
  }
}

