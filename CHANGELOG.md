# Cisco CML2 Cloud provisioning tooling

Lists the changes for the tool releases.

## Version 0.1.1

- depend on 0.6.2 of the CML Terraform provider
- updated documentation / README
  - changed some wording / corrected some sections (fixes #1)
  - added proxy section
  - added a troubleshooting section
- ensure the AWS provider uses the region provided in `config.yml`
- use the new `ignore_errors` flag when waiting for the system to become ready

## Version 0.1.0

Initial release of the tooling with support for AWS metal flavors.
