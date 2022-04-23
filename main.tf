resource "aws_vpc" "csc_vpc" {
  cidr_block           = "10.123.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "dev"
  }
}

resource "aws_subnet" "csc_public_subnet" {
  vpc_id                  = aws_vpc.csc_vpc.id
  cidr_block              = "10.123.0.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "us-west-2a"

  tags = {
    Name = "dev-public"
  }
}

resource "aws_internet_gateway" "csc_internet_gateway" {
  vpc_id = aws_vpc.csc_vpc.id

  tags = {
    Name : "dev-igw"
  }
}

resource "aws_route_table" "csc_public_rt" {
  vpc_id = aws_vpc.csc_vpc.id

  tags = {
    Name = "dev-public-rt"
  }
}

resource "aws_route" "default_route" {
  route_table_id         = aws_route_table.csc_public_rt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.csc_internet_gateway.id
}

resource "aws_route_table_association" "csc_public_association" {
  subnet_id      = aws_subnet.csc_public_subnet.id
  route_table_id = aws_route_table.csc_public_rt.id
}

resource "aws_security_group" "csc_security_group" {
  name        = "dev-security-group"
  description = "dev security group"
  vpc_id      = aws_vpc.csc_vpc.id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["187.188.39.95/32"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_key_pair" "csc_auth" {
  key_name   = "csckey"
  public_key = file("~/.ssh/more_key_pairs/csckey.pub")
}

resource "aws_instance" "dev_node" {
  instance_type          = "t2.micro"
  ami                    = data.aws_ami.server_ami.id
  key_name               = aws_key_pair.csc_auth.id
  vpc_security_group_ids = [aws_security_group.csc_security_group.id]
  subnet_id              = aws_subnet.csc_public_subnet.id
  user_data              = file("userdata.tpl")

  root_block_device {
    volume_size = 10
  }

  provisioner "local-exec" {
    command = templatefile("${var.host_os}-ssh-config.tpl", {
      hostname     = self.public_ip,
      user         = "ubuntu"
      identityfile = "C:\\Users\\ahr\\.ssh\\more_key_pairs\\csckey"
    })
    interpreter = var.host_os == "windows" ? ["Powershell", "-Command"] : ["bash", "-c"]
  }

  tags = {
    Name = "dev-node"
  }
}