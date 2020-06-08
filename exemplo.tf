provider "aws" {
  shared_credentials_file = "~/.aws/credentials"
  profile    = "default"
  region     = "us-east-1"
}

data "aws_vpc" "default" {
  id = "vpc-ad1642d7"
}

resource "aws_s3_bucket" "exemplo" {
  bucket = "terraform-dependencia"
  acl    = "private"
}

resource "aws_key_pair" "deployer" {
  key_name   = "terraform-teste"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAABJQAAAQEAui7JRtAzgtYcQTofU/uz0uV/uEDmHN0YcLMzgexvaSvfLx/xhEz2uEnZOeLdXtykQNf/WkBFGbKypqWsp0qZEzFXBxlSrlHqzFHimntJsWNXesRRbZIZXOausL98GxOn1dbTePaiwSJ3OU7NT8ZUoJIQKjDOouNQ/VDr/nxcCXbs0i8YTY8+GiONDywe/7SG4Frq0XRfd6f1oDuNGwHVBu6vZZYhAkvuy/L5FzG+omZCPMKansI0n7CcQpDDtRjoEjyk+73zcgkd0B/ste3R8T10JmwRhYb+8gvTQLwwAZ9uneZ1Mc6qDXzrd2wgjpYReHouMMpsQSX1Q+Pwp9CiCw== rsa-key-20200114"
}

resource "aws_security_group" "allow_ssh" {
  name        = "allow_ssh"
  description = "Allow ssh inbound traffic"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    # TLS (change to whatever ports you need)
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    # Please restrict your ingress to only necessary IPs and ports.
    # Opening to 0.0.0.0/0 can lead to security vulnerabilities.
    cidr_blocks = ["0.0.0.0/0"]
  }
}
resource "aws_instance" "example" {
  ami           = "ami-04763b3055de4860b"
  instance_type = "t2.micro"
  key_name = aws_key_pair.deployer.key_name
  security_groups = [aws_security_group.allow_ssh.name]

  connection {
    type     = "ssh"
    user     = "ubuntu"
    private_key = file("id_rsa")
    host     = self.public_ip
  }

  provisioner "file" {
    source      = "install_nginx.sh"
    destination = "/tmp/install_nginx.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo chmod +x /tmp/install_nginx.sh",
      "/tmp/install_nginx.sh"
    ]
  }

  provisioner "local-exec" {
    command = "echo ${aws_instance.example.public_ip} > ip_address.txt"
  }

  depends_on = [aws_s3_bucket.exemplo]
}

resource "aws_eip" "ip" {
    vpc = true
    instance = aws_instance.example.id
}