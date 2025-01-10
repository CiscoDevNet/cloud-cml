# Cisco CML2 Cloud provisioning tooling

Lists the changes for the tool releases.

## Version 2.8.0

- using "aws\_" and "azure\_" prefixes to provide tokens and IDs in the environment (see `.envrc.example`)
- adapt tooling to work with 2.8.0 (move base OS from 20.04 to 24.04)
- allow to use the `allowed_ipv4_subnets` also for Azure
- improve network manager handling while provisioning
- licensing now uses the PCL instead of curl and bash
- documentation improvements and fixes

## Version 2.7.2

- added the AWS mini variant which does not manage any network resources, the
  subnet and security group ID
- change elastic IP allocation for AWS from dynamic to static to make it work
  again
- this is the last release to support CML 2.7 and before
- changed the versioning to match the CML version so that it's easier to find the proper version / release of cloud-cml which works with the CML version to be used

## Version 0.3.0

- allow cluster deployments on AWS.
  - manage and use a non-default VPC
  - optionally allow to use an already existing VPC and gateway
  - allow to enable EBS encryption (fixes #8)
  - a `cluster` section has been added to the config file.  Some keywords have changed (`hostname` -> `controller_hostname`).  See also a new "Cluster" section in the [AWS documentation](documentation/AWS.md)
- introduce secret managers for storing secrets.
  - supported are dummy (use raw_secrets, as before), Conjur and Vault
  - also support randomly generated secrets
  - by default, the dummy module with random secrets is configured
  - the license token secret needs to be configured regardless
- use the CML .pkg software distribution file instead of multiple .deb packages (this is a breaking change -- you need to change the configuration and upload the .pkg to cloud storage instead of the .deb. `deb` -> `software`.
- the PaTTY customization script has been removed.  PaTTY is included in the .pkg. Its installation and configuration is now controlled by a new keyword `enable_patty` in the `common` section of the config.
  > [!NOTE]
  > Poll time is hard-coded to 5 seconds in the `cml.sh` script.  If a longer poll time and/or additional options like console and VNC access are needed then this needs to be changed manually in the script.
- add a common script file which has currently a function to determine whether the instance is a controller or not.  This makes it easier to install only controller relevant elements and omit them on computes (usable within the main `cml.sh` file as well as in the customization scripts).
- explicitly disable bridge0 and also disable the virl2-bridge-setup.py script by inserting `exit()` as the 2nd line.  This will ensure that service restarts will not try to re-create the bridge0 interface. This will be obsolete / a no-op with 2.7.1 which includes a "skip bridge creation" flag.
- each instance will be rebooted at the end of cloud-init to come up with newly installed software / kernel and in a clean state.
- add configuration option `cfg.aws.vpc_id` and `cfg.aws.gw_id` to specify the VPC and gateway ID that should be used. If left empty, then a custom VPC ID will be created (fixes #9)

## Version 0.2.1

- allow to select provider using a script and split out TF providers
- added prepare.sh / prepare.bat script for this purpose
- initial state has AWS ON (config.yml example also is set to AWS)
- fixed image paths for the AWS documentation
- mentioned the necessary "prepare" step in the overall README.md
- fix copying from cloud-storage to instance storage
- address 16KB cloud-init limitation in AWS (not entirely removed but pushed out farther)

## Version 0.2.0

- added multi-cloud support
- big re-factor to accommodate different cloud-targets
- currently supported: AWS and Azure
- updated documentation, split into different cloud providers

## Version 0.1.4

- improved upload tool
  - better error handling in case no images are available
  - modified help text
- completely reworked the AWS policy creation section to provide step-by-step instructions to accurately describe the policy creation process
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
