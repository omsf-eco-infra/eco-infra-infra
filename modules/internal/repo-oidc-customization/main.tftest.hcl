mock_provider "github" {
  alias = "mock"
}

variables {
  role_configurations = [
    {
      github_repository  = "example-org/example-repo"
      include_claim_keys = ["repo", "context", "workflow_ref"]
      ready_role_arn     = "arn:aws:iam::123456789012:role/example-deploy"
    },
    {
      github_repository  = "example-org/example-repo"
      include_claim_keys = ["repo", "context", "workflow_ref"]
      ready_role_arn     = "arn:aws:iam::123456789012:role/example-test"
    },
  ]
}

run "repository_customization" {
  command = plan
  providers = {
    github = github.mock
  }

  plan_options {
    refresh = false
  }

  assert {
    condition     = github_actions_repository_oidc_subject_claim_customization_template.workflow.repository == "example-repo"
    error_message = "The GitHub provider resource should receive the repository name."
  }

  assert {
    condition     = !github_actions_repository_oidc_subject_claim_customization_template.workflow.use_default
    error_message = "The repository must opt into its custom subject template."
  }

  assert {
    condition     = tolist(github_actions_repository_oidc_subject_claim_customization_template.workflow.include_claim_keys) == tolist(["repo", "context", "workflow_ref"])
    error_message = "The customization should apply the standardized ordered claims."
  }

  assert {
    condition = tolist(terraform_data.role_trust_policies_ready.input) == tolist([
      "arn:aws:iam::123456789012:role/example-deploy",
      "arn:aws:iam::123456789012:role/example-test",
    ])
    error_message = "The dependency barrier should contain every sorted role ARN."
  }

  assert {
    condition     = output.github_repository == "example-org/example-repo"
    error_message = "The module should output the full repository name."
  }
}

run "reject_empty_contracts" {
  command = plan
  providers = {
    github = github.mock
  }

  variables {
    role_configurations = []
  }

  expect_failures = [var.role_configurations]
}

run "reject_mixed_repositories" {
  command = plan
  providers = {
    github = github.mock
  }

  variables {
    role_configurations = [
      {
        github_repository  = "example-org/example-repo"
        include_claim_keys = ["repo", "context", "workflow_ref"]
        ready_role_arn     = "arn:aws:iam::123456789012:role/example-deploy"
      },
      {
        github_repository  = "example-org/other-repo"
        include_claim_keys = ["repo", "context", "workflow_ref"]
        ready_role_arn     = "arn:aws:iam::123456789012:role/example-test"
      },
    ]
  }

  expect_failures = [var.role_configurations]
}

run "pass_through_claim_keys" {
  command = plan
  providers = {
    github = github.mock
  }

  variables {
    role_configurations = [{
      github_repository  = "example-org/example-repo"
      include_claim_keys = ["repo", "job_workflow_ref"]
      ready_role_arn     = "arn:aws:iam::123456789012:role/example-deploy"
    }]
  }

  assert {
    condition     = tolist(github_actions_repository_oidc_subject_claim_customization_template.workflow.include_claim_keys) == tolist(["repo", "job_workflow_ref"])
    error_message = "The repository customization should pass through the role contract's ordered claim keys."
  }
}

run "reject_mixed_claim_keys" {
  command = plan
  providers = {
    github = github.mock
  }

  variables {
    role_configurations = [
      {
        github_repository  = "example-org/example-repo"
        include_claim_keys = ["repo", "context", "workflow_ref"]
        ready_role_arn     = "arn:aws:iam::123456789012:role/example-deploy"
      },
      {
        github_repository  = "example-org/example-repo"
        include_claim_keys = ["repo", "job_workflow_ref"]
        ready_role_arn     = "arn:aws:iam::123456789012:role/example-test"
      },
    ]
  }

  expect_failures = [var.role_configurations]
}
