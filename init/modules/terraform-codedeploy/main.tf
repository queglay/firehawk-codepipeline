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

resource "aws_codedeploy_app" "firehawk_app" {
  name = "firehawk-codedeploy-app"
  tags = { "deployment_group" : "firehawk-test-deploy-group"}
}

resource "aws_sns_topic" "firehawk_sns_topic" {
  name = "firehawk-codedeploy-sns"
}

resource "aws_codedeploy_deployment_config" "firehawk_deployment_config" {
  deployment_config_name = "firehawk-deployment-config"

#   minimum_healthy_hosts {
#     type  = "HOST_COUNT"
#     value = 2
#   }
}

resource "aws_codedeploy_deployment_group" "firehawk_deployment_group" {
  app_name              = aws_codedeploy_app.firehawk_app.name
  deployment_group_name = "firehawk-deployment-group"
  service_role_arn      = aws_iam_role.firehawk_role.arn
  deployment_config_name = aws_codedeploy_deployment_config.firehawk_deployment_config.id

  ec2_tag_set {
    ec2_tag_filter {
      key   = "deployment_group"
      type  = "KEY_AND_VALUE"
      value = "firehawk-test-deploy-group"
    }

    # ec2_tag_filter {
    #   key   = "filterkey2"
    #   type  = "KEY_AND_VALUE"
    #   value = "filtervalue"
    # }
  }

  trigger_configuration {
    trigger_events     = ["DeploymentFailure"]
    trigger_name       = "example-trigger"
    trigger_target_arn = aws_sns_topic.firehawk_sns_topic.arn
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