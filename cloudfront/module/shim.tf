data "archive_file" "default_route_lambda" {
  type        = "zip"
  output_path = "${path.module}/default-route.zip"

  source {
    content  = file("${path.module}/scripts/default-route.js")
    filename = "index.js"
  }
}

resource "aws_lambda_function" "default_origin_shim" {
  count            = length(local.default_origin) < 1 ? 1 : 0
  filename         = data.archive_file.default_route_lambda.output_path
  function_name    = "${var.suga.stack_id}-cloudfront-default-origin-shim"
  role             = aws_iam_role.lambda_edge_origin_request[0].arn
  handler          = "index.handler"
  source_code_hash = data.archive_file.default_route_lambda.output_base64sha256
  runtime          = "nodejs22.x"
  timeout          = 5
  memory_size      = 128
  publish          = true
}

resource "aws_lambda_function_url" "default_origin_shim" {
  count              = length(aws_lambda_function.default_origin_shim) > 0 ? 1 : 0
  function_name      = aws_lambda_function.default_origin_shim[0].function_name
  authorization_type = "AWS_IAM"
  depends_on         = [aws_lambda_function.default_origin_shim[0]]
}

resource "aws_lambda_permission" "allow_cloudfront_to_execute_lambda_shim" {
  count         = length(aws_lambda_function.default_origin_shim) > 0 ? 1 : 0
  function_name = aws_lambda_function.default_origin_shim[0].function_name
  principal     = "cloudfront.amazonaws.com"
  action        = "lambda:InvokeFunctionUrl"
  source_arn    = aws_cloudfront_distribution.distribution.arn
  depends_on    = [aws_lambda_function.default_origin_shim[0], aws_cloudfront_distribution.distribution]
}

locals {
  actual_default_origin = length(local.default_origin) > 0 ? local.default_origin : { "default-lambda-shim" : aws_lambda_function_url.default_origin_shim[0].function_url }
}