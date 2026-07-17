mock_provider "aws" {
  alias = "mock"
}

mock_provider "github" {
  alias = "mock"
}

override_data {
  target = data.aws_iam_openid_connect_provider.github_by_url
  values = {
    arn            = "arn:aws:iam::123456789012:oidc-provider/token.actions.githubusercontent.com"
    client_id_list = ["sts.amazonaws.com"]
  }
}

override_resource {
  target = aws_iam_role.github_actions
  values = {
    arn = "arn:aws:iam::123456789012:role/example-github-actions"
  }
}

variables {
  role_name             = "example-github-actions"
  role_description      = "Example workflow role"
  max_session_duration  = 7200
  force_detach_policies = true
  github_repository     = "example-org/example-repo"
  role_secret_name      = "AWS_EXAMPLE_ROLE_ARN"

  trusted_workflows = [
    {
      workflow_filename = "deploy.yaml"
      context = {
        type  = "branch"
        value = "main"
      }
    },
    {
      workflow_filename = "deploy.yaml"
      context = {
        type = "pull_request"
      }
    },
    {
      workflow_filename = "release.yml"
      context = {
        type  = "tag"
        value = "v*"
      }
    },
    {
      workflow_filename = "deploy.yaml"
      workflow_ref      = "refs/heads/main"
      context = {
        type  = "environment"
        value = "production:blue"
      }
    },
    {
      workflow_filename = "maintenance.yml"
      context = {
        type = "any"
      }
    },
  ]

  inline_policies = {
    deploy = jsonencode({
      Version = "2012-10-17"
      Statement = [{
        Effect   = "Allow"
        Action   = ["s3:ListAllMyBuckets"]
        Resource = "*"
      }]
    })
  }

  managed_policy_arns = {
    readonly = "arn:aws:iam::123456789012:policy/example-readonly"
  }

  tags = {
    managed_by = "tofu"
  }
}

run "role_configuration" {
  command = plan
  providers = {
    aws    = aws.mock
    github = github.mock
  }

  plan_options {
    refresh = false
  }

  assert {
    condition     = aws_iam_role.github_actions.name == "example-github-actions"
    error_message = "The role should use the requested name."
  }

  assert {
    condition     = aws_iam_role.github_actions.max_session_duration == 7200
    error_message = "The role should use the requested maximum session duration."
  }

  assert {
    condition     = aws_iam_role.github_actions.force_detach_policies
    error_message = "The role should preserve force_detach_policies."
  }

  assert {
    condition     = aws_iam_role.github_actions.description == "Example workflow role"
    error_message = "The role should use the requested description."
  }

  assert {
    condition     = aws_iam_role.github_actions.tags == tomap(var.tags)
    error_message = "The role should use the requested tags."
  }

  assert {
    condition     = output.github_oidc_provider_arn == "arn:aws:iam::123456789012:oidc-provider/token.actions.githubusercontent.com"
    error_message = "The module should discover and expose the GitHub OIDC provider ARN."
  }

  assert {
    condition     = github_actions_secret.role_arn.repository == "example-repo"
    error_message = "The role secret should be created in the configured repository."
  }

  assert {
    condition     = github_actions_secret.role_arn.secret_name == "AWS_EXAMPLE_ROLE_ARN"
    error_message = "The role secret should use the requested name."
  }

  assert {
    condition     = github_actions_secret.role_arn.value == "arn:aws:iam::123456789012:role/example-github-actions"
    error_message = "The role secret should contain the role ARN."
  }

  assert {
    condition     = aws_iam_role_policy.inline["deploy"].name == "deploy"
    error_message = "Inline policy map keys should provide stable policy names."
  }

  assert {
    condition     = aws_iam_role_policy.inline["deploy"].role == aws_iam_role.github_actions.name
    error_message = "Inline policies should be attached to the managed role."
  }

  assert {
    condition = (
      jsondecode(aws_iam_role_policy.inline["deploy"].policy).Version == "2012-10-17" &&
      length(jsondecode(aws_iam_role_policy.inline["deploy"].policy).Statement) == 1 &&
      jsondecode(aws_iam_role_policy.inline["deploy"].policy).Statement[0].Effect == "Allow" &&
      tolist(jsondecode(aws_iam_role_policy.inline["deploy"].policy).Statement[0].Action) == tolist(["s3:ListAllMyBuckets"]) &&
      jsondecode(aws_iam_role_policy.inline["deploy"].policy).Statement[0].Resource == "*"
    )
    error_message = "Inline policy resources should preserve the complete requested policy document."
  }

  assert {
    condition     = aws_iam_role_policy_attachment.managed["readonly"].policy_arn == "arn:aws:iam::123456789012:policy/example-readonly"
    error_message = "Managed policy map entries should create stable attachments."
  }

  assert {
    condition     = aws_iam_role_policy_attachment.managed["readonly"].role == aws_iam_role.github_actions.name
    error_message = "Managed policies should be attached to the managed role."
  }

  assert {
    condition = output.oidc_subjects == sort([
      "repo:example-org/example-repo:ref:refs/heads/main:workflow_ref:example-org/example-repo/.github/workflows/deploy.yaml@refs/heads/main",
      "repo:example-org/example-repo:pull_request:workflow_ref:example-org/example-repo/.github/workflows/deploy.yaml@refs/pull/*/merge",
      "repo:example-org/example-repo:ref:refs/tags/v*:workflow_ref:example-org/example-repo/.github/workflows/release.yml@refs/tags/v*",
      "repo:example-org/example-repo:environment:production%3Ablue:workflow_ref:example-org/example-repo/.github/workflows/deploy.yaml@refs/heads/main",
      "repo:example-org/example-repo:*:workflow_ref:example-org/example-repo/.github/workflows/maintenance.yml@refs/*",
    ])
    error_message = "OIDC subjects should encode every exact workflow/context combination."
  }

  assert {
    condition     = output.repository_oidc_configuration.github_repository == "example-org/example-repo"
    error_message = "The repository customization contract should carry the repository."
  }

  assert {
    condition     = output.repository_oidc_configuration.include_claim_keys == ["repo", "context", "workflow_ref"]
    error_message = "The repository customization contract should use the standardized claim order."
  }

  assert {
    condition     = jsondecode(aws_iam_role.github_actions.assume_role_policy) == jsondecode(output.assume_role_policy_json)
    error_message = "The managed role and policy output should use the same trust policy document."
  }

  assert {
    condition = (
      jsondecode(aws_iam_role.github_actions.assume_role_policy).Version == "2012-10-17" &&
      length(jsondecode(aws_iam_role.github_actions.assume_role_policy).Statement) == 1 &&
      jsondecode(aws_iam_role.github_actions.assume_role_policy).Statement[0].Sid == "GitHubActionsAssumeRole" &&
      jsondecode(aws_iam_role.github_actions.assume_role_policy).Statement[0].Effect == "Allow" &&
      jsondecode(aws_iam_role.github_actions.assume_role_policy).Statement[0].Action == "sts:AssumeRoleWithWebIdentity"
    )
    error_message = "The trust policy should contain one allow statement for GitHub OIDC role assumption."
  }

  assert {
    condition = (
      jsondecode(aws_iam_role.github_actions.assume_role_policy).Statement[0].Principal.Federated == output.github_oidc_provider_arn &&
      jsondecode(aws_iam_role.github_actions.assume_role_policy).Statement[0].Condition.StringEquals["token.actions.githubusercontent.com:aud"] == "sts.amazonaws.com" &&
      tolist(jsondecode(aws_iam_role.github_actions.assume_role_policy).Statement[0].Condition.StringLike["token.actions.githubusercontent.com:sub"]) == tolist(output.oidc_subjects)
    )
    error_message = "The trust policy should restrict the provider, audience, and subjects to the configured GitHub workflows."
  }

  assert {
    condition     = !strcontains(aws_iam_role.github_actions.assume_role_policy, "job_workflow_ref")
    error_message = "The trust policy must not use AWS's unsupported independent job_workflow_ref condition."
  }
}

run "explicit_oidc_provider_arn" {
  command = plan
  providers = {
    aws    = aws.mock
    github = github.mock
  }

  variables {
    github_oidc_provider_arn = "arn:aws:iam::123456789012:oidc-provider/token.actions.githubusercontent.com"
  }

  override_data {
    target = data.aws_iam_openid_connect_provider.github_by_arn
    values = {
      client_id_list = ["sts.amazonaws.com"]
    }
  }

  assert {
    condition     = output.github_oidc_provider_arn == var.github_oidc_provider_arn
    error_message = "An explicit GitHub OIDC provider ARN should be preserved."
  }
}

run "reject_invalid_repository" {
  command = plan
  providers = {
    aws    = aws.mock
    github = github.mock
  }

  variables {
    github_repository = "missing-owner"
  }

  expect_failures = [var.github_repository]
}

run "reject_empty_workflows" {
  command = plan
  providers = {
    aws    = aws.mock
    github = github.mock
  }

  variables {
    trusted_workflows = []
  }

  expect_failures = [var.trusted_workflows]
}

run "reject_invalid_context" {
  command = plan
  providers = {
    aws    = aws.mock
    github = github.mock
  }

  variables {
    trusted_workflows = [{
      workflow_filename = "deploy.yaml"
      workflow_ref      = "refs/heads/main"
      context = {
        type = "environment"
      }
    }]
  }

  expect_failures = [var.trusted_workflows]
}

run "reject_invalid_workflow_filename" {
  command = plan
  providers = {
    aws    = aws.mock
    github = github.mock
  }

  variables {
    trusted_workflows = [{
      workflow_filename = "nested/deploy.yaml"
      workflow_ref      = "refs/heads/main"
      context = {
        type  = "branch"
        value = "main"
      }
    }]
  }

  expect_failures = [var.trusted_workflows]
}

run "reject_invalid_workflow_ref" {
  command = plan
  providers = {
    aws    = aws.mock
    github = github.mock
  }

  variables {
    trusted_workflows = [{
      workflow_filename = "deploy.yaml"
      workflow_ref      = "main"
      context = {
        type  = "branch"
        value = "main"
      }
    }]
  }

  expect_failures = [var.trusted_workflows]
}

run "reject_environment_without_workflow_ref" {
  command = plan
  providers = {
    aws    = aws.mock
    github = github.mock
  }

  variables {
    trusted_workflows = [{
      workflow_filename = "deploy.yaml"
      context = {
        type  = "environment"
        value = "production"
      }
    }]
  }

  expect_failures = [var.trusted_workflows]
}

run "reject_malformed_inline_policy" {
  command = plan
  providers = {
    aws    = aws.mock
    github = github.mock
  }

  variables {
    inline_policies = {
      broken = "not-json"
    }
  }

  expect_failures = [var.inline_policies]
}

run "reject_invalid_session_duration" {
  command = plan
  providers = {
    aws    = aws.mock
    github = github.mock
  }

  variables {
    max_session_duration = 3599
  }

  expect_failures = [var.max_session_duration]
}

run "reject_invalid_role_secret_name" {
  command = plan
  providers = {
    aws    = aws.mock
    github = github.mock
  }

  variables {
    role_secret_name = "GITHUB_ROLE_ARN"
  }

  expect_failures = [var.role_secret_name]
}
