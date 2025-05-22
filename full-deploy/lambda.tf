resource "aws_lambda_function" "status_check_lambda" {
  count         = length(var.availability_zones)
  function_name = "${var.prefix}-status-check-lambda-${count.index}"
  filename      = "lambda.zip"
  handler       = "new_lambda.lambda_handler"
  runtime       = "python3.13"
  timeout       = 30

  role = aws_iam_role.lambda_exec.arn

  environment {
    variables = {
    vpcendpoint1 = aws_vpc_endpoint.gwlbe_ns_endpoint[count.index].id
    vpcendpoint2 = aws_vpc_endpoint.gwlbe_ns_endpoint[1 - count.index].id
      routetable   = aws_route_table.sec_txgw_rt[count.index].id
      region       = var.region
    }
  }
}

resource "aws_lambda_permission" "allow_cloudwatch_alarm" {
  count         = length(var.availability_zones)
  statement_id  = "AllowCloudWatchInvoke"
  action        = "lambda:InvokeFunction"
  principal     = "cloudwatch.amazonaws.com"
  function_name = aws_lambda_function.status_check_lambda[count.index].function_name
  source_arn    = aws_cloudwatch_metric_alarm.ec2_status_check_alarm[count.index].arn
}

resource "aws_iam_role" "lambda_exec" {
  name = "LambdaExecutionRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Effect = "Allow"
        Sid    = ""
      }
    ]
  })
}

resource "aws_iam_role_policy" "lambda_policy" {
  name = "LambdaExecutionPolicy"
  role = aws_iam_role.lambda_exec.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "logs:*",
          "cloudwatch:*"
        ]
        Effect   = "Allow"
        Resource = "*"
      },
      {
        Action = [
          "ec2:CreateRoute",
          "ec2:DeleteRoute",
          "ec2:DescribeRouteTables", # Allows describing the route table
          "ec2:ModifyRouteTable"     # Allows modifying the route table
        ]
        Effect   = "Allow"
        Resource = "*"
      }
    ]
  })
}