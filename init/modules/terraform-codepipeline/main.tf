data "aws_ssm_parameter" "git_repo_id" {
  name = "/firehawk/resourcetier/${var.resourcetier}/git_repo_id"
}

resource "aws_codepipeline" "codepipeline" {
  depends_on = [aws_iam_role_policy.codepipeline_policy]
  name       = "tf-firehawk-deploy-pipeline"
  role_arn   = aws_iam_role.codepipeline_role.arn

  artifact_store {
    location = aws_s3_bucket.codepipeline_bucket.bucket
    type     = "S3"

    # encryption_key {
    #   id   = data.aws_kms_alias.s3kmskey.arn
    #   type = "KMS"
    # }
  }

  stage {
    name = "SourceInfra"

    action {
      name             = "SourceInfra"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeStarSourceConnection"
      version          = "1"
      output_artifacts = ["source_infra_app_output"]

      configuration = {
        ConnectionArn        = aws_codestarconnections_connection.my_github_connection.arn
        FullRepositoryId     = data.aws_ssm_parameter.git_repo_id.value
        BranchName           = "main"
        OutputArtifactFormat = "CODEBUILD_CLONE_REF"
        # see https://docs.aws.amazon.com/codepipeline/latest/userguide/action-reference-CodestarConnectionSource.html#action-reference-CodestarConnectionSource-config
      }
    }
  }

  stage {
    name = "BuildInfra"

    action {
      name             = "BuildInfra"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      # The app itself defines it's source when not running in codepipeline, but in this case code pipeline defines the source via input_artifacts
      input_artifacts  = ["source_infra_app_output"]
      output_artifacts = ["build_infra_app_output"]
      version          = "1"

      configuration = {
        ProjectName = "firehawk-createapp"
      }
    }
  }

  stage {
    name = "DeployInfra"
    action {
      name            = "DeployInfra"
      category        = "Deploy"
      owner           = "AWS"
      provider        = "CodeDeploy"
      input_artifacts = ["build_infra_app_output"]
      version         = "1"
      configuration = {
        ApplicationName     = "firehawk-codedeploy-infra-app"
        DeploymentGroupName = "firehawk-deployment-group"
      }
    }
  }
  # stage {
  #   name = "SourceTest"

  #   action {
  #     name             = "SourceTest"
  #     category         = "Source"
  #     owner            = "AWS"
  #     provider         = "CodeStarSourceConnection"
  #     version          = "1"
  #     output_artifacts = ["source_test_app_output"]

  #     configuration = {
  #       ConnectionArn        = aws_codestarconnections_connection.my_github_connection.arn
  #       FullRepositoryId     = "firehawkvfx/firehawk-pdg-test"
  #       BranchName           = "main"
  #       OutputArtifactFormat = "CODEBUILD_CLONE_REF"
  #       # see https://docs.aws.amazon.com/codepipeline/latest/userguide/action-reference-CodestarConnectionSource.html#action-reference-CodestarConnectionSource-config
  #     }
  #   }
  # }
  stage {
    name = "BuildTest"

    action {
      name             = "BuildTest"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      # The app itself defines it's source when not running in codepipeline, but in this case code pipeline defines the source via input_artifacts
      input_artifacts  = ["source_infra_app_output"]
      output_artifacts = ["source_test_app_output"]
      version          = "1"

      configuration = {
        ProjectName = "firehawk-testapp"
      }
    }
  }
  stage {
    name = "TestApp"
    action {
      name            = "TestApp"
      category        = "Deploy"
      owner           = "AWS"
      provider        = "CodeDeploy"
      input_artifacts = ["source_test_app_output"] # TODO artifacts need to be configured correctly.
      version         = "1"
      configuration = {
        ApplicationName     = "firehawk-codedeploy-test-app"
        DeploymentGroupName = "firehawk-test-group"
      }
    }
  }
  stage {
    name = "Approve-Destroy"
    action {
      name     = "ApproveDestroy"
      category = "Approval"
      owner    = "AWS"
      provider = "Manual"
      version  = "1"
      configuration = {
        # NotificationArn = "${var.approve_sns_arn}"
        CustomData = "Approval of this step will configure the app to destroy Firehawk infrastructure."
        # ExternalEntityLink = "${var.approve_url}"
      }
    }
  }
  stage {
    name = "Build-Destroy"
    action {
      name             = "BuildDestroy"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      input_artifacts  = ["source_infra_app_output"]
      output_artifacts = ["build_destroy_output"]
      version          = "1"

      configuration = {
        ProjectName = "firehawk-destroyapp"
      }
    }
  }
  stage {
    name = "Destroy"
    action {
      name            = "Deploy"
      category        = "Deploy"
      owner           = "AWS"
      provider        = "CodeDeploy"
      input_artifacts = ["build_destroy_output"]
      version         = "1"
      configuration = {
        ApplicationName     = "firehawk-codedeploy-infra-app"
        DeploymentGroupName = "firehawk-deployment-group"
      }
    }
  }
  stage {
    name = "Destroy-Deployer"
    action {
      name             = "DestroyDeployer"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      input_artifacts  = ["source_infra_app_output"]
      output_artifacts = ["deploy_destroy_output"]
      version          = "1"

      configuration = {
        ProjectName = "firehawk-destroydeployerapp"
      }
    }
  }
}

resource "aws_codestarconnections_connection" "my_github_connection" {
  name          = "firehawk-github-connection"
  provider_type = "GitHub"
}

resource "aws_s3_bucket" "codepipeline_bucket" {
  bucket = "firehawk-codepipeline-deploy.${var.bucket_extension}"
}

resource "aws_s3_bucket_acl" "codepipeline_bucket_acl" {
  bucket = aws_s3_bucket.codepipeline_bucket.id
  acl    = "private"
}

resource "aws_iam_role" "codepipeline_role" {
  name = "codepipeline-deploy-role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "codepipeline.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "codepipeline_policy" {
  name = "codepipeline_policy"
  role = aws_iam_role.codepipeline_role.id

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "s3:GetObject",
                "s3:GetObjectVersion",
                "s3:GetBucketVersioning",
                "s3:PutObjectAcl",
                "s3:PutObject"
            ],
            "Resource": [
                "${aws_s3_bucket.codepipeline_bucket.arn}",
                "${aws_s3_bucket.codepipeline_bucket.arn}/*"
            ]
        },
        {
            "Effect": "Allow",
            "Action": [
                "codestar-connections:UseConnection"
            ],
            "Resource": "${aws_codestarconnections_connection.my_github_connection.arn}"
        },
        {
            "Effect": "Allow",
            "Action": [
                "codebuild:BatchGetBuilds",
                "codebuild:StartBuild"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "codedeploy:CreateDeployment",
                "codedeploy:GetApplication",
                "codedeploy:GetApplicationRevision",
                "codedeploy:GetDeployment",
                "codedeploy:GetDeploymentConfig",
                "codedeploy:RegisterApplicationRevision"
            ],
            "Resource": "*"
        }
    ]
}
EOF
}

# data "aws_kms_alias" "s3kmskey" {
#   name = "alias/myKmsKey"
# }

