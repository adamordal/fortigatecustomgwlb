# ---------------------------------------------------------------------------------------------------------------------
# CREATE SECURITY GROUPS
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_security_group" "fw-mgmt-sg" {
  name        = "fw-mgmt-sg-${random_id.deployment_id.hex}"
  description = "Management interfaces for the firewall"
  vpc_id      = aws_vpc.sec_vpc.id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = var.fw_mgmt_sg_list
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "fw-mgmt-sg-${random_id.deployment_id.hex}"
  }

  depends_on = [aws_vpc.sec_vpc]
}

resource "aws_security_group" "fw-data-sg" {
  name        = "fw-data-sg-${random_id.deployment_id.hex}"
  description = "Dataplane interfaces for the firewall"
  vpc_id      = aws_vpc.sec_vpc.id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "fw-data-sg-${random_id.deployment_id.hex}"
  }

  depends_on = [aws_vpc.sec_vpc]
}