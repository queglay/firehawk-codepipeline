provider "aws" {}
resource "aws_iam_role" "firehawk_role" {
  name = "FirehawkCodeDeployRole"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Service": "codedeploy.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "AWSCodeDeployRole" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSCodeDeployRole"
  role       = aws_iam_role.firehawk_role.name
}

resource "aws_codedeploy_app" "firehawk_infra_app" {
  name = "firehawk-codedeploy-infra-app"
  tags = { "deployment_group" : "firehawk-provisioner-deploy-group"}
}

resource "aws_codedeploy_app" "firehawk_test_app" {
  name = "firehawk-codedeploy-test-app"
  tags = { "deployment_group" : "firehawk-rendernode-test-group"}
}

resource "aws_sns_topic" "firehawk_infra_sns_topic" {
  name = "firehawk-codedeploy-infra-sns"
}

resource "aws_sns_topic" "firehawk_test_sns_topic" {
  name = "firehawk-codedeploy-test-sns"
}

resource "aws_codedeploy_deployment_group" "firehawk_infra_deployment_group" {
  app_name              = aws_codedeploy_app.firehawk_infra_app.name
  deployment_group_name = "firehawk-deployment-group"
  service_role_arn      = aws_iam_role.firehawk_role.arn
  deployment_config_name = "CodeDeployDefault.OneAtATime"

  ec2_tag_set {
    ec2_tag_filter {
      key   = "deployment_group"
      type  = "KEY_AND_VALUE"
      value = "firehawk-provisioner-deploy-group"
    }
  }

  trigger_configuration {
    trigger_events     = ["DeploymentFailure"]
    trigger_name       = "example-trigger"
    trigger_target_arn = aws_sns_topic.firehawk_infra_sns_topic.arn
  }

  auto_rollback_configuration {
    enabled = false
    events  = ["DEPLOYMENT_FAILURE"]
  }

  alarm_configuration {
    alarms  = ["my-alarm-name"]
    enabled = false
  }
}

resource "aws_codedeploy_deployment_group" "firehawk_test_deployment_group" {
  app_name              = aws_codedeploy_app.firehawk_test_app.name
  deployment_group_name = "firehawk-test-group"
  service_role_arn      = aws_iam_role.firehawk_role.arn
  deployment_config_name = "CodeDeployDefault.OneAtATime"

  ec2_tag_set {
    ec2_tag_filter {
      key   = "deployment_group"
      type  = "KEY_AND_VALUE"
      value = "firehawk-rendernode-test-group"
    }
  }

  trigger_configuration {
    trigger_events     = ["DeploymentFailure"]
    trigger_name       = "example-trigger"
    trigger_target_arn = aws_sns_topic.firehawk_test_sns_topic.arn
  }

  auto_rollback_configuration {
    enabled = false
    events  = ["DEPLOYMENT_FAILURE"]
  }

  alarm_configuration {
    alarms  = ["my-alarm-name"]
    enabled = false
  }
}