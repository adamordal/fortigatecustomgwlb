## ---------------------------------------------------------------------------------------------------------------------
## CREATE Endpoint Service and Endpoint for Gateway Load Balancer
## ---------------------------------------------------------------------------------------------------------------------
resource "aws_lb" "sec_gwlb" {
  name               = "sec-gwlb-${random_id.deployment_id.hex}"
  load_balancer_type = "gateway"
  #enable_cross_zone_load_balancing = true

  subnets    = [for i in range(2) : aws_subnet.pafw_data_subnet[i].id]
  depends_on = [aws_subnet.pafw_data_subnet]
}

resource "aws_lb_target_group" "sec_gwlb_tg" {
  name                 = "sec-gwlb-tg-${random_id.deployment_id.hex}"
  port                 = 6081
  protocol             = "GENEVE"
  vpc_id               = aws_vpc.sec_vpc.id
  target_type          = "ip"
  deregistration_delay = 30


  stickiness {
    enabled = true
    type    = "source_ip_dest_ip"
  }
  target_failover {
    on_deregistration = "rebalance"
    on_unhealthy      = "rebalance"
  }



  health_check {
    port                = 8008
    protocol            = "TCP"
    interval            = 10
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

resource "aws_lb_target_group_attachment" "sec_gwlb_tg_attachment" {
  count            = length(var.availability_zones)
  target_group_arn = aws_lb_target_group.sec_gwlb_tg.arn
  target_id        = aws_network_interface.fw-data-eni[count.index].private_ip
  port             = 6081

  depends_on = [aws_instance.firewall_instance]
}

resource "aws_lb_listener" "sec_gwlb_listener" {
  load_balancer_arn = aws_lb.sec_gwlb.arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.sec_gwlb_tg.arn
  }
  depends_on = [aws_lb.sec_gwlb, aws_lb_listener.sec_gwlb_listener]
}

resource "aws_vpc_endpoint_service" "sec_gwlb_endpoint_service" {
  acceptance_required        = false
  gateway_load_balancer_arns = [aws_lb.sec_gwlb.arn]
}

resource "aws_vpc_endpoint" "gwlbe_ns_endpoint" {
  count        = length(var.availability_zones)
  service_name = aws_vpc_endpoint_service.sec_gwlb_endpoint_service.service_name
  subnet_ids   = [aws_subnet.gwlbe_ns_subnet[count.index].id]
  #subnet_ids        = [aws_subnet.gwlbe_ns_subnet[0].id]
  vpc_endpoint_type = "GatewayLoadBalancer"
  vpc_id            = aws_vpc.sec_vpc.id
}
