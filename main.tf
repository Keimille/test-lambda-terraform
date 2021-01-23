provider "aws" {
  version = "~> 2.0"

  region = "us-east-1"
}

#### SNS Configuration ####
resource "aws_sns_topic" "test" {
  name            = "terraform_test"
  delivery_policy = <<EOF
{
  "http": {
    "defaultHealthyRetryPolicy": {
      "minDelayTarget": 20,
      "maxDelayTarget": 20,
      "numRetries": 3,
      "numMaxDelayRetries": 0,
      "numNoDelayRetries": 0,
      "numMinDelayRetries": 0,
      "backoffFunction": "linear"
    },
    "disableSubscriptionOverrides": false,
    "defaultThrottlePolicy": {
      "maxReceivesPerSecond": 1
    }
  }
}
EOF
}
#### SQS Configuration ####
resource "aws_sqs_queue" "test_example_queue" {
  name                      = "test_example_queue"
  delay_seconds             = 90
  max_message_size          = 2048
  message_retention_seconds = 86400
  receive_wait_time_seconds = 10
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.terraform_queue_deadletter.arn
    maxReceiveCount     = 4
  })

  tags = {
    Environment = "test"
  }
}

resource "aws_sqs_queue" "terraform_queue_deadletter" {
  name = "terraform_queue_deadletter"
}

resource "aws_sns_topic_subscription" "test_example_queue_target" {
  topic_arn = aws_sns_topic.test.arn
  protocol  = "sqs"
  endpoint  = aws_sqs_queue.test_example_queue.arn
}



resource "aws_sqs_queue_policy" "test" {
  queue_url = aws_sqs_queue.test_example_queue.id

  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Id": "sqspolicy",
  "Statement": [
    {
      "Sid": "First",
      "Effect": "Allow",
      "Principal": "*",
      "Action": "sqs:SendMessage",
      "Resource": "aws_sqs_queue.test_example_queue.arn",
      "Condition": {
        "ArnEquals": {
          "aws:SourceArn": "aws_sns_topic.test.arn"
        }
      }
    }
  ]
}
POLICY
}

#### Lambda Configuration ####
resource "aws_lambda_function" "test_example_lambda" {
  filename         = "./lambda/example.zip"
  function_name    = "test_example"
  role             = aws_iam_role.lambda_role.arn
  handler          = "example.handler"
  source_code_hash = "data.archive_file.lambda_zip.output_base64sha256"
  runtime          = "python3.6"
}

#### IAM Configuration ####
resource "aws_iam_role" "lambda_role" {
  name               = "LambdaRole"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
        "Action": "sts:AssumeRole",
        "Effect": "Allow",
        "Principal": {
            "Service": "lambda.amazonaws.com"
        }
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "lambda_role_sqs_policy" {
  name   = "AllowSQSPermissions"
  role   = aws_iam_role.lambda_role.id
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "sqs:ChangeMessageVisibility",
        "sqs:DeleteMessage",
        "sqs:GetQueueAttributes",
        "sqs:ReceiveMessage"
      ],
      "Effect": "Allow",
      "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "lambda_role_logs_policy" {
  name   = "LambdaRolePolicy"
  role   = aws_iam_role.lambda_role.id
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Effect": "Allow",
      "Resource": "*"
    }
  ]
}
EOF
}