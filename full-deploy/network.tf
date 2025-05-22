## ---------------------------------------------------------------------------------------------------------------------
## CREATE VPC AND SUBNETS
## ---------------------------------------------------------------------------------------------------------------------

resource "aws_vpc" "sec_vpc" {
  cidr_block = var.vpc_cidr
  tags = {
    Name = "sec-vpc-${random_id.deployment_id.hex}"
  }
}

resource "aws_internet_gateway" "sec_vpc_igw" {
  vpc_id = aws_vpc.sec_vpc.id

  tags = {
    Name = "sec-vpc-igw-${random_id.deployment_id.hex}"
  }
  depends_on = [aws_vpc.sec_vpc]
}

resource "aws_subnet" "pafw_mgmt_subnet" {
  count             = length(var.availability_zones)
  vpc_id            = aws_vpc.sec_vpc.id
  cidr_block        = cidrsubnet(join("/", [split("/", aws_vpc.sec_vpc.cidr_block)[0], "23"]), 5, 0 + count.index)
  availability_zone = var.availability_zones[count.index]
  tags = {
    Name = "pafw-mgmt-subnet-${var.availability_zones[count.index]}-${random_id.deployment_id.hex}"
  }
  depends_on = [aws_vpc.sec_vpc]
}

resource "aws_subnet" "gwlbe_ns_subnet" {
  count             = length(var.availability_zones)
  vpc_id            = aws_vpc.sec_vpc.id
  cidr_block        = cidrsubnet(join("/", [split("/", aws_vpc.sec_vpc.cidr_block)[0], "23"]), 5, 5 + count.index)
  availability_zone = var.availability_zones[count.index]
  tags = {
    Name = "sec-ns-subnet-${var.availability_zones[count.index]}-${random_id.deployment_id.hex}"
  }
  depends_on = [aws_vpc.sec_vpc]
}


resource "aws_subnet" "pafw_data_subnet" {
  count             = length(var.availability_zones)
  vpc_id            = aws_vpc.sec_vpc.id
  cidr_block        = cidrsubnet(join("/", [split("/", aws_vpc.sec_vpc.cidr_block)[0], "23"]), 5, 15 + count.index)
  availability_zone = var.availability_zones[count.index]
  tags = {
    Name = "sec-data-subnet-${var.availability_zones[count.index]}-${random_id.deployment_id.hex}"
  }
  depends_on = [aws_vpc.sec_vpc]
}

resource "aws_subnet" "sec_txgw_subnet" {
  count             = length(var.availability_zones)
  vpc_id            = aws_vpc.sec_vpc.id
  cidr_block        = cidrsubnet(join("/", [split("/", aws_vpc.sec_vpc.cidr_block)[0], "23"]), 5, 20 + count.index)
  availability_zone = var.availability_zones[count.index]
  tags = {
    Name = "sec-txgw-subnet-${var.availability_zones[count.index]}-${random_id.deployment_id.hex}"
  }
  depends_on = [aws_vpc.sec_vpc]
}

resource "aws_subnet" "sec_natgw_subnet" {
  count             = length(var.availability_zones)
  vpc_id            = aws_vpc.sec_vpc.id
  cidr_block        = cidrsubnet(join("/", [split("/", aws_vpc.sec_vpc.cidr_block)[0], "23"]), 5, 25 + count.index)
  availability_zone = var.availability_zones[count.index]
  tags = {
    Name = "sec-natgw-subnet-${var.availability_zones[count.index]}-${random_id.deployment_id.hex}"
  }
  depends_on = [aws_vpc.sec_vpc]
}

## ---------------------------------------------------------------------------------------------------------------------
## CREATE NAT GATEWAY
## ---------------------------------------------------------------------------------------------------------------------

resource "aws_eip" "natgw_eip" {
  count      = length(var.availability_zones)
  domain     = "vpc"
  depends_on = [aws_vpc.sec_vpc]
}

resource "aws_nat_gateway" "sec_nat_gw" {
  count         = length(var.availability_zones)
  allocation_id = aws_eip.natgw_eip[count.index].id
  subnet_id     = aws_subnet.sec_natgw_subnet[count.index].id
  depends_on    = [aws_subnet.sec_natgw_subnet, aws_eip.natgw_eip]
}

#### ---------------------------------------------------------------------------------------------------------------------
#### CREATE TXGWASSOCIATION
#### ---------------------------------------------------------------------------------------------------------------------

data "aws_ec2_transit_gateway" "transit_gw" {
  id = var.transit_gw_id
}

resource "aws_ec2_transit_gateway_vpc_attachment" "sec_txgw_attach" {
  subnet_ids             = aws_subnet.sec_txgw_subnet[*].id
  transit_gateway_id     = data.aws_ec2_transit_gateway.transit_gw.id
  vpc_id                 = aws_vpc.sec_vpc.id
  appliance_mode_support = "enable"

  tags = {
    Name = "sec-txgw-attach-${random_id.deployment_id.hex}"
  }

  depends_on = [aws_subnet.sec_txgw_subnet]
}

#### ---------------------------------------------------------------------------------------------------------------------
#### CREATE ROUTE TABLES AND ASSOCIATIONS
#### ---------------------------------------------------------------------------------------------------------------------

resource "aws_route_table" "pafw_mgmt_rt" {
  count  = length(var.availability_zones)
  vpc_id = aws_vpc.sec_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.sec_vpc_igw.id
    #    nat_gateway_id = aws_nat_gateway.sec_nat_gw[count.index].id
  }

  tags = {
    Name = "pafw-mgmt-rt-${var.availability_zones[count.index]}-${random_id.deployment_id.hex}"
  }

  depends_on = [aws_internet_gateway.sec_vpc_igw]
}

resource "aws_route_table_association" "pafw_mgmt_rt_association" {
  count          = length(var.availability_zones)
  subnet_id      = aws_subnet.pafw_mgmt_subnet[count.index].id
  route_table_id = aws_route_table.pafw_mgmt_rt[count.index].id
  depends_on     = [aws_subnet.pafw_mgmt_subnet, aws_route_table.pafw_mgmt_rt]
}

#### ---------------------------------------------------------------------------------------------------------------------
resource "aws_route_table" "gwlbe_ns_rt" {
  count  = length(var.availability_zones)
  vpc_id = aws_vpc.sec_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.sec_nat_gw[count.index].id
  }

  route {
    cidr_block         = "10.0.0.0/8"
    transit_gateway_id = data.aws_ec2_transit_gateway.transit_gw.id
  }
  route {
    cidr_block         = "172.16.0.0/12"
    transit_gateway_id = data.aws_ec2_transit_gateway.transit_gw.id
  }
  route {
    cidr_block         = "192.168.0.0/16"
    transit_gateway_id = data.aws_ec2_transit_gateway.transit_gw.id
  }
  tags = {
    Name = "gwlbe-ns-rt-${var.availability_zones[count.index]}-${random_id.deployment_id.hex}"
  }

  depends_on = [aws_ec2_transit_gateway_vpc_attachment.sec_txgw_attach]
}

resource "aws_route_table_association" "gwlbe_ns_rt_association" {
  count          = length(var.availability_zones)
  subnet_id      = aws_subnet.gwlbe_ns_subnet[count.index].id
  route_table_id = aws_route_table.gwlbe_ns_rt[count.index].id
  depends_on     = [aws_subnet.gwlbe_ns_subnet, aws_route_table.gwlbe_ns_rt]
}


#### ---------------------------------------------------------------------------------------------------------------------
resource "aws_route_table" "pafw_data_rt" {
  count  = length(var.availability_zones)
  vpc_id = aws_vpc.sec_vpc.id

  #  route {
  #    cidr_block = "0.0.0.0/0"
  #    nat_gateway_id = aws_nat_gateway.sec_nat_gw[count.index].id
  #  }
  #
  #  route {
  #    cidr_block         = "10.0.0.0/8"
  #    transit_gateway_id = data.aws_ec2_transit_gateway.transit_gw.id
  #  }
  #
  #  route {
  #    cidr_block         = "172.16.0.0/12"
  #    transit_gateway_id = data.aws_ec2_transit_gateway.transit_gw.id
  #  }
  #
  #  route {
  #    cidr_block         = "192.168.0.0/16"
  #    transit_gateway_id = data.aws_ec2_transit_gateway.transit_gw.id
  #  }

  tags = {
    Name = "pafw-data-rt-${var.availability_zones[count.index]}-${random_id.deployment_id.hex}"
  }

  depends_on = [aws_internet_gateway.sec_vpc_igw]
}

resource "aws_route_table_association" "pafw_data_rt_association" {
  count          = length(var.availability_zones)
  subnet_id      = aws_subnet.pafw_data_subnet[count.index].id
  route_table_id = aws_route_table.pafw_data_rt[count.index].id
  depends_on     = [aws_subnet.pafw_data_subnet, aws_route_table.pafw_data_rt]
}
## ---------------------------------------------------------------------------------------------------------------------
resource "aws_route_table" "sec_txgw_rt" {
  count  = length(var.availability_zones)
  vpc_id = aws_vpc.sec_vpc.id

  route {
    cidr_block      = "0.0.0.0/0"
    vpc_endpoint_id = aws_vpc_endpoint.gwlbe_ns_endpoint[count.index].id
    #vpc_endpoint_id = aws_vpc_endpoint.gwlbe_ns_endpoint.id
  }

  tags = {
    Name = "sec-txgw-rt-${var.availability_zones[count.index]}-${random_id.deployment_id.hex}"
  }

  #depends_on = [aws_vpc_endpoint.sec_gwlb_endpoint]
}

resource "aws_route_table_association" "sec_txgw_rt_association" {
  count          = length(var.availability_zones)
  subnet_id      = aws_subnet.sec_txgw_subnet[count.index].id
  route_table_id = aws_route_table.sec_txgw_rt[count.index].id
  depends_on     = [aws_subnet.sec_txgw_subnet, aws_route_table.sec_txgw_rt]
}
## ---------------------------------------------------------------------------------------------------------------------
resource "aws_route_table" "sec_natgw_rt" {
  count  = length(var.availability_zones)
  vpc_id = aws_vpc.sec_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.sec_vpc_igw.id
  }

  route {
    cidr_block      = "10.0.0.0/8"
    vpc_endpoint_id = aws_vpc_endpoint.gwlbe_ns_endpoint[count.index].id
  }

  route {
    cidr_block      = "172.16.0.0/12"
    vpc_endpoint_id = aws_vpc_endpoint.gwlbe_ns_endpoint[count.index].id
  }

  route {
    cidr_block      = "192.168.0.0/16"
    vpc_endpoint_id = aws_vpc_endpoint.gwlbe_ns_endpoint[count.index].id
  }

  tags = {
    Name = "sec-natgw-rt-${var.availability_zones[count.index]}-${random_id.deployment_id.hex}"
  }

  depends_on = [aws_vpc_endpoint.gwlbe_ns_endpoint]
}

resource "aws_route_table_association" "sec_natgw_rt_association" {
  count          = length(var.availability_zones)
  subnet_id      = aws_subnet.sec_natgw_subnet[count.index].id
  route_table_id = aws_route_table.sec_natgw_rt[count.index].id
  depends_on     = [aws_subnet.sec_natgw_subnet, aws_route_table.sec_natgw_rt]
}
## ---------------------------------------------------------------------------------------------------------------------
