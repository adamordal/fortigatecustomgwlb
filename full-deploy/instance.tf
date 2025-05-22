# ---------------------------------------------------------------------------------------------------------------------
# CREATE NETWORK INTERFACES AND EIPs
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_network_interface" "fw-mgmt-eni" {
  count             = length(var.availability_zones)
  subnet_id         = aws_subnet.pafw_mgmt_subnet[count.index].id
  security_groups   = [aws_security_group.fw-mgmt-sg.id]
  source_dest_check = "false"
  tags = {
    Name = "fw-mgmt-eni-${var.availability_zones[count.index]}-${random_id.deployment_id.hex}"
  }
}

resource "aws_network_interface" "fw-data-eni" {
  count             = length(var.availability_zones)
  subnet_id         = aws_subnet.pafw_data_subnet[count.index].id
  security_groups   = [aws_security_group.fw-data-sg.id]
  source_dest_check = "false"
  tags = {
    Name = "fw-data-eni-${var.availability_zones[count.index]}-${random_id.deployment_id.hex}"
  }
}

resource "aws_eip" "fw-mgmt-eip" {
  count             = length(var.availability_zones)
  domain            = "vpc"
  network_interface = aws_network_interface.fw-mgmt-eni[count.index].id
  tags = {
    Name = "fw-mgmt-eip-${var.availability_zones[count.index]}-${random_id.deployment_id.hex}"
  }
  depends_on = [aws_network_interface.fw-mgmt-eni, aws_instance.firewall_instance]
}

#resource "aws_eip" "fw-data-eip" {
#  count             = length(var.availability_zones)
#  domain            = "vpc"
#  network_interface = aws_network_interface.fw-data-eni[count.index].id
#  tags = {
#    Name = "fw-data-eip-${var.availability_zones[count.index]}-${random_id.deployment_id.hex}"
#  }
#  depends_on = [aws_network_interface.fw-data-eni, aws_instance.firewall_instance]
#}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE FIREWALL INSTANCE
# ---------------------------------------------------------------------------------------------------------------------

data "aws_network_interface" "vpcendpointip" {
  count      = length(var.availability_zones)
  depends_on = [aws_vpc_endpoint.gwlbe_ns_endpoint]
  filter {
    name   = "vpc-id"
    values = ["${aws_vpc.sec_vpc.id}"]
  }
  filter {
    name   = "status"
    values = ["in-use"]
  }
  filter {
    name   = "description"
    values = ["*ELB*"]
  }
  filter {
    name   = "availability-zone"
    values = ["${var.availability_zones[count.index]}"]
  }
}

data "template_file" "fgtvm_conf" {
  count    = length(var.availability_zones)
  template = file("${path.module}/fgtvm.conf")
  vars = {
    hostname   = "FW-${var.availability_zones[count.index]}-${random_id.deployment_id.hex}"
    endpointip = "${data.aws_network_interface.vpcendpointip[count.index].private_ip}"
    gateway    = cidrhost(aws_subnet.pafw_data_subnet[count.index].cidr_block, 1)
    cidr       = cidrhost(var.vpc_cidr, 0)
    netmask    = cidrnetmask(var.vpc_cidr)
  }
}

resource "aws_instance" "firewall_instance" {
  count         = length(var.availability_zones)
  ami           = var.firewall_ami_id
  instance_type = var.instance_type
  monitoring    = true

  network_interface {
    network_interface_id = aws_network_interface.fw-data-eni[count.index].id
    device_index         = 1
  }

  network_interface {
    network_interface_id = aws_network_interface.fw-mgmt-eni[count.index].id
    device_index         = 0
  }

  user_data = data.template_file.fgtvm_conf[count.index].rendered

  key_name = var.key_pair
  tags = {
    Name = "FW-${var.availability_zones[count.index]}-${random_id.deployment_id.hex}"
  }
}

resource "aws_cloudwatch_metric_alarm" "ec2_status_check_alarm" {
  count               = length(var.availability_zones)
  alarm_name          = "EC2StatusCheckFailed-${aws_instance.firewall_instance[count.index].id}"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "StatusCheckFailed"
  namespace           = "AWS/EC2"
  period              = 60
  statistic           = "Maximum"
  threshold           = 1
  alarm_description   = "Triggers when EC2 instance status check fails"
  dimensions = {
    InstanceId = aws_instance.firewall_instance[count.index].id
  }

  alarm_actions = [
    aws_lambda_function.status_check_lambda[count.index].arn
  ]

  ok_actions = [
    aws_lambda_function.status_check_lambda[count.index].arn
  ]

  treat_missing_data = "breaching"
}
