# Cisco CML2 Cloud provisioning tooling

Lists the changes for the tool releases.

## Version 0.2.0

- added multi-cloud support
- big re-factor to accommodate different cloud-targets
- currently supported: AWS and Azure
- updated documentation, split into different cloud providers

## Version 0.1.4

- improved upload tool
  - better error handling in case no images are available
  - modified help text
- completely reworked the AWS policy creation section to
  provide step-by-step instructions to accurately describe the
  policy creation process
- added the current ref-plat images to the `config.yml` file
- provided the current .pkg file name to the `config.yml` file

## Version 0.1.3

- documentation update
- make PATty installation script more robust
- fix location for .pkg file in the `upload-images-to-aws.sh` script

## Version 0.1.2

Documentation update. Added a diagram for policy dependencies

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
