# ecoinfra-tfstate

This directory includes the OpenTofu/Terraform files to set up the Terraform
backend, which will store the Terraform state file in an S3 bucket and handle
locking with DynamoDB.

Note that the actual backend file we use is in the root directory.
