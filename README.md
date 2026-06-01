# eco-infra-infra

*Infrastructure modules by OMSF's Ecosystem Infrastructure team.*

In the course of our work building out various cloud-based tools for OMSF and beyond, we have found ourselves repeating a number of patterns in our infrastructure code.
This repository is an attempt to capture those patterns in reusable modules.
On one hand, this is a standard "don't repeat yourself" effort, intended to reduce our maintenance burden by centralizing common code in one place.
On the other hand, we hope this repository can be useful as part of our efforts to teach infrastructure as code to other OMSF developers, by providing examples of what simple reusable components look like.

## Structure

* `modules/`: This directory contains the reusable modules themselves.

## Modules

### End-User Modules

A few of our modules are intended to be used directly by end-users, rather than being building blocks for other tools.

* `tfstate-aws-backend`: A module to create a Terraform state bucket in AWS.

### Building Block Modules

These modules are intended to be used as building blocks for other tools, and are likely to be reused across many projects.
