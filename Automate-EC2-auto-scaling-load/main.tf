provider "aws" {
  region = "us-east-1"
}
resource "aws_instance" "my_instance" {
  ami           = "ami-0866a3c8686eaeeba" # Use the appropriate AMI ID
  instance_type = "t2.micro"
  key_name      = "devops-key"
}

resource "aws_autoscaling_group" "asg" {
  desired_capacity     = 2
  max_size             = 3
  min_size             = 1
  vpc_zone_identifier  = ["subnet-00df84bef9a03f709"] # Replace with your subnet ID
  launch_configuration = aws_launch_configuration.lc.id
}

resource "aws_launch_configuration" "lc" {
  image_id      = "ami-0866a3c8686eaeeba"
  instance_type = "t2.micro"
  key_name      = "devops-key"
}

resource "aws_lb" "my_lb" {
  name               = "my-load-balancer"
  internal           = false
  load_balancer_type = "application"
  subnets            = ["subnet-00df84bef9a03f709", "subnet-02ba1dab666c6b03e"]
}

resource "aws_route53_record" "dns" {
  zone_id = "Z1023623C2UEC19CD8JH" # Replace with your Route 53 hosted zone ID
  name    = "samsorzone10.com"
  type    = "A"

  alias {
    name                   = aws_lb.my_lb.dns_name
    zone_id                = aws_lb.my_lb.zone_id
    evaluate_target_health = false
  }
}
