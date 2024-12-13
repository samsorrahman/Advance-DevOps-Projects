<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">

</head>
<body>
  <h1>Creating A Highly Available Two-Tier Architecture With Terraform (Security Best Practices)</h1>

  <h2>Objective:</h2>
  <ul>
    <li>Create a highly available two-tier AWS architecture containing the following:</li>
    <ul>
      <li>A. Custom VPC with:
        <ul>
          <li>2 Public Subnets for the Web Server Tier</li>
          <li>2 Private Subnets for the RDS Tier</li>
          <li>Appropriate route tables</li>
        </ul>
      </li>
      <li>B. Launch an EC2 Instance with Apache webserver in each public web tier subnet</li>
      <li>C. One RDS MySQL Instance (micro) in the private RDS subnets</li>
      <li>D. Security Groups properly configured for needed resources (web servers, RDS)</li>
    </ul>

  <h2>Prerequisites</h2>
  <ul>
    <li>AWS Free-Tier Account</li>
    <li>IDE with Terraform capabilities (I’ll be using Cloud9)</li>
    <li>Knowledge of basic Shell Scripting functionalities</li>
  </ul>

  <h2>Two-Tier Architecture Overview:</h2>
  <p>Before we dive into the action steps needed to complete the tasks above, it is important to understand what a two-tier architecture is and why it is beneficial in real-world use cases.</p>
  <p>A two-tier architecture refers to an infrastructure design pattern where a web application is divided into two separate layers: a web server tier and a database tier. The web server tier provides the user interface and runs the web application logic, while the database tier is responsible for storing the application data. The web server tier is typically deployed on public subnets to allow access to the internet, while the database tier is deployed on private subnets to enhance security.</p>
  <p>Using Terraform to create a two-tier architecture can help simplify the process of creating and managing complex infrastructure environments, making it easier to support scalable and highly available web applications.</p>

  <h2>Create Configuration Files</h2>
  <p>For the sake of keeping our code manageable, we want to create different files for different operations. For this mission, we will have a few moving parts and as a result, we’ll need the following files created: <code>ec2.tf</code>, <code>rds.tf</code>, <code>vpc.tf</code>, and <code>variables.tf</code>.</p>

  <p>It’s also worth noting that everything configured from the command line on this mission can also be configured within the AWS management console but it is best practice to configure your code in the command line. Configuring your code in the command line will allow for better automation and easier scalability as opposed to manual entry from the console.</p>

  <h3>Create vpc.tf file</h3>
  <p><strong>Note:</strong> There are a number of different ways to create a two-tier architecture with high availability. For this project, we will keep it fairly simple with our infrastructure. We will be creating a Multi-AZ deployment which ensures that our application remains available even if one AZ becomes unavailable.</p>

  <pre><code>
provider "aws" {
  region = "us-east-1"
  alias  = "vpc-alias"
}

resource "aws_vpc" "vpc22" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "my-vpc"
  }
}

resource "aws_subnet" "public1" {
  cidr_block              = "10.0.1.0/24"
  vpc_id                  = aws_vpc.vpc22.id
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true
  tags = {
    Name = "public1"
  }
}

resource "aws_subnet" "public2" {
  cidr_block              = "10.0.2.0/24"
  vpc_id                  = aws_vpc.vpc22.id
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = true
  tags = {
    Name = "public2"
  }
}

resource "aws_subnet" "private1" {
  cidr_block        = "10.0.3.0/24"
  vpc_id            = aws_vpc.vpc22.id
  availability_zone = "us-east-1a"
  tags = {
    Name = "private1"
  }
}

resource "aws_subnet" "private2" {
  cidr_block        = "10.0.4.0/24"
  vpc_id            = aws_vpc.vpc22.id
  availability_zone = "us-east-1b"
  tags = {
    Name = "private2"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.vpc22.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.vpc22.id
  }

  tags = {
    Name = "public"
  }
}

resource "aws_route_table" "private1" {
  vpc_id = aws_vpc.vpc22.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.vpc22.id
  }

  tags = {
    Name = "private1"
  }
}

resource "aws_route_table" "private2" {
  vpc_id = aws_vpc.vpc22.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.vpc22.id
  }

  tags = {
    Name = "private2"
  }
}

resource "aws_internet_gateway" "vpc22" {
  vpc_id = aws_vpc.vpc22.id

  tags = {
    Name = "vpc22"
  }
}

resource "aws_nat_gateway" "vpc22" {
  allocation_id = aws_eip.vpc22.id
  subnet_id     = aws_subnet.public1.id

  tags = {
    Name = "vpc22"
  }
}

resource "aws_eip" "vpc22" {
  vpc = true
}

resource "aws_route_table_association" "public1" {
  subnet_id      = aws_subnet.public1.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public2" {
  subnet_id      = aws_subnet.public2.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private1" {
  subnet_id      = aws_subnet.private1.id
  route_table_id = aws_route_table.private1.id
}
  </code></pre>

  <h3>Create the ec2.tf file</h3>
  <pre><code>
provider "aws" {
  region = "us-east-1"
}

resource "aws_instance" "web1" {
  ami                    = "ami-0cbf5e746b95ddc88"
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.public1.id
  vpc_security_group_ids = [aws_security_group.web.id]
  key_name               = "my-key"
  user_data              = &lt;&lt;-EOF
              #!/bin/bash
              yum update -y
              yum install -y httpd
              systemctl start httpd
              systemctl enable httpd
              EOF

  tags = {
    Name = "web1"
  }
}

resource "aws_instance" "web2" {
  ami                    = "ami-0cbf5e746b95ddc88"
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.public2.id
  vpc_security_group_ids = [aws_security_group.web.id]
  key_name               = "my-key"
  user_data              = &lt;&lt;-EOF
              #!/bin/bash
              yum update -y
              yum install -y httpd
              systemctl start httpd
              systemctl enable httpd
              EOF

  tags = {
    Name = "web2"
  }
}

resource "aws_security_group" "web" {
  name        = "web"
  description = "Allow HTTP traffic"
  vpc_id      = aws_vpc.vpc22.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
  </code></pre>

  <h3>Create the rds.tf file</h3>
  <pre><code>
provider "aws" {
  region = "us-east-1"
  alias  = "rds-alias"
}

resource "aws_db_subnet_group" "vpc22" {
  name       = "vpc22"
  subnet_ids = [aws_subnet.private1.id, aws_subnet.private2.id]
}

resource "aws_db_instance" "vpc22" {
  identifier             = "vpc22"
  engine                 = "mysql"
  instance_class         = "db.t2.micro"
  allocated_storage      = 5
  storage_type           = "gp2"
  db_subnet_group_name   = aws_db_subnet_group.vpc22.name
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  db_name                = "vpc22"
  username               = "admin"
  password               = "mypassword"

  tags = {
    Name = "vpc22"
  }
}

resource "aws_security_group" "rds_sg" {
  name        = "rds_sg"
  description = "Allow MySQL traffic"
  vpc_id      = aws_vpc.vpc22.id

  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.web.id]
  }
}
  </code></pre>

  <h3>Create the variables.tf file</h3>
  <pre><code>
variable "aws_access_key" {}
variable "aws_secret_key" {}
variable "region" {
  default = "us-east-1"
}
  </code></pre>

  <h2>Initialization</h2>
  <p>Once all the files are configured, run the <code>terraform init</code> command to initialize and acknowledge the changes made.</p>

    <p>terraform plan</p>
    <p>terraform apply</p>
<p>Output</p>
</body>
</html>

![Screenshot 2024-12-13 173154](https://github.com/user-attachments/assets/77c4c1f8-5542-44c6-9409-ab6fdd41621a)


![Screenshot 2024-12-13 173230](https://github.com/user-attachments/assets/40635ad8-bbd1-440d-91ce-366ff3dac767)

![Screenshot 2024-12-13 173259](https://github.com/user-attachments/assets/922c75ac-2962-4887-942a-040341f6f03d)

