# README

Version 0.3.1, November 29 2024

With CML 2.7, you can run CML instances on Azure and AWS.  We have tested CML deployments using this tool chain in both clouds.  **The use of this tool is considered BETA**.  The tool has certain requirements and prerequisites which are described in this README and in the [documentation](documentation) directory.

*It is very likely that this tool chain can not be used "as-is"*.  It should be forked and adapted to specific customer requirements and environments.

> [!NOTE]
>
> Please ensure that `prepare.sh` is run first as this sets key variable names



> [!IMPORTANT]
>
> **Version 2.7 vs 2.8**
>
> CML2 version 2.8 has been released in November 2024.  As CML 2.8 uses Ubuntu 24.04 as the base operating system, cloud-cml needs to accommodate for that during image selection when bringing up the VM on the hosting service (AWS, Azure, ...).  This means that going forward, cloud-cml will support 2.8 and not 2.7 anymore.  This release will be the last that does support CML 2.7!
>
> **Support:**
>
> - For customers with a valid service contract, CML cloud deployments are supported by TAC within the outlined constraints.  Beyond this, support is done with best effort as cloud environments, requirements and policy can differ to a great extent.
> - With no service contract, support is done on a best effort basis via the issue tracker.
>
> **Features and capabilities:** Changes to the deployment tooling will be considered like any other feature by adding them to the product roadmap.  This is done at the discretion of the CML team.
>
> **Error reporting:** If you encounter any errors or problems that might be related to the code in this repository then please open an issue on the [Github issue tracker for this repository](https://github.com/CiscoDevNet/cloud-cml/issues).

> [!IMPORTANT]
> Read the section below about [cloud provider selection](#important-cloud-provider-selection) (prepare script).

## CML Utilities

This project includes scripts that integrate with [cmlutils](https://pypi.org/project/cmlutils/), a command-line tool for managing CML labs. To use cmlutils:

1. Install the package:
```bash
pip install cmlutils
```

2. Generate the .virlrc configuration:
```bash
python scripts/generate_virlrc.py
```

3. Source the configuration:
```bash
source .virlrc
```

4. You can now use cmlutils commands:
```bash
# List labs
cml ls

# Stop all labs
cml down --all
```

## General requirements

The tooling uses Terraform to deploy CML instances in the Cloud. It's therefore required to have a functional Terraform installation on the computer where this tool chain should be used.

Furthermore, the user needs to have access to the cloud service. E.g. credentials and permissions are needed to create and modify the required resources. Required resources are

- service accounts
- storage services
- compute and networking services

The tool chain / build scripts and Terraform can be installed on the on-prem CML controller or, when this is undesirable due to support concerns, on a separate Linux instance.

That said, the tooling also runs on macOS with tools installed via [Homebrew](https://brew.sh/). Or on Windows with WSL. However, Windows hasn't been tested by us.

### Preparation

Some of the steps and procedures outlined below are preparation steps and only need to be done once. Those are

- cloning of the repository
- installation of software (Terraform, cloud provider CLI tooling)
- creating and configuring of a service account, including the creation of associated access credentials
- creating the storage resources and uploading images and software into it
- creation of an SSH key pair and making the public key available to the cloud service
- editing the `config.yml` configuration file including the selection of the cloud service, an instance flavor, region, license token and other parameters
- optionally setting up S3 backend for state management

#### Important: Cloud provider selection

The tooling supports multiple cloud providers (currently AWS and Azure).  Not everyone wants both providers.  The **default configuration is set to use AWS only**.  If Azure should be used either instead or in addition then the following steps are mandatory:

1. Run the `prepare.sh` script to modify and prepare the tool chain.  If on Windows, use `prepare.bat`.  You can actually choose to use both, if that's what you want.
    - The script will ask for a prefix for AWS resources (or generate a random one)
    - If AWS is enabled, you'll be offered to set up S3 backend for state management
    - The script will create necessary configurations and backups
2. Configure the proper target ("aws" or "azure") in the configuration file

The first step is unfortunately required, since it is impossible to dynamically select different cloud configurations within the same Terraform HCL configuration.  See [this SO link](https://stackoverflow.com/questions/70428374/how-to-make-the-provider-configuration-optional-and-based-on-the-condition-in-te) for more some context and details.

The default "out-of-the-box" configuration is AWS, so if you want to run on Azure, don't forget to run the prepare script.

#### State Management

The tool now supports using S3 as a backend for Terraform state management. When running `prepare.sh`:

1. You'll be asked if you want to use S3 for state management
2. If yes, the script will:
    - Check for an existing state bucket
    - Create the bucket and DynamoDB table if they don't exist
    - Configure Terraform to use the S3 backend
    - Migrate any existing state

Benefits of using S3 backend:
- State locking via DynamoDB
- Encrypted state storage
- State versioning
- Team collaboration support

#### Known Issues

When using bare metal instances (e.g., `c5.metal`), you might encounter timeout errors during deployment:

```
│ Error: CML2 Provider Error
│
│   with module.ready.data.cml2_system.state,
│   on modules/readyness/main.tf line 7, in data "cml2_system" "state":
│    7: data "cml2_system" "state" {
│
│ ran into timeout (max 15m)
```

This is expected as metal instances take longer to start/stop. The provider has been configured with extended timeouts (30 minutes), but you may still see this error. The deployment will continue to work despite this error.

#### Resource Naming and Prefixes

The `prepare.sh` script handles all resource naming and prefixes:

1. You'll be prompted to enter a prefix or use a randomly generated one
2. This prefix will be used for all AWS resources (buckets, instances, etc.)
3. The script automatically updates all relevant files with the new prefix
4. No personal identifiers need to be stored in the repository

Example resources that use the prefix:
- S3 bucket: `<prefix>-aws-cml`
- State bucket: `<prefix>-aws-cml-tfstate`
- Instance names: `cml-dublin-<prefix>`

The following fields in config.yml will be automatically updated:
```yaml
aws:
  region: # Set based on user input
  availability_zone: # Set based on region
  bucket: # Set to <prefix>-aws-cml
common:
  key_name: # Set to cml-<region>-<prefix>
```

The prepare script will:
1. Ask for your preferred AWS region
2. Map the region to a city name based on location:
   - EMEA: dublin (eu-west-1), london (eu-west-2), paris (eu-west-3), etc.
   - US: virginia (us-east-1), ohio (us-east-2), california (us-west-1), etc.
   - APAC: singapore (ap-southeast-1), sydney (ap-southeast-2), tokyo (ap-northeast-1), etc.
3. Configure all region-specific settings automatically
4. Use the region city in resource naming

You can leave these fields empty in the repository as they will be populated by the prepare script.

#### Managing secrets

> [!WARNING]
> It is a best practice to **not** keep your CML secrets and passwords in Git!

CML cloud supports these storage methods for the required platform and application secrets:

- Raw secrets in the configuration file (as supported with previous versions)
- Random secrets by not specifiying any secrets
- [Hashicorp Vault](https://www.vaultproject.io/)
- [CyberArk Conjur](https://www.conjur.org/)

See the sections below for additional details how to use and manage secrets.

##### Referencing secrets

You can refer to the secret maintained in the secrets manager by updating `config.yml` appropriately.  If you use the `dummy` secrets manager, it will use the `raw_secret` as specified in the `config.yml` file, and the secrets will **not** be protected.

```yaml
secret:
  manager: conjur
  secrets:
    app:
      username: <virl_username>
      # Example using Conjur
      path: example-org/example-project/secret/<virl_username>_password
```

Refer to the `.envrc.example` file for examples to set up environment variables to use an external secrets manager.

##### Random secrets

If you want random passwords to be generated when applying, based on [random_password](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/password), leave the `raw_secret` undefined:

```yaml
secret:
  manager: dummy
  secrets:
    app:
      username: <virl_username>
      # raw_secret: # Undefined
```

> [!NOTE]
>
> You can retrieve the generated passwords after applying with `terraform output cml2secrets`.

The included default `config.yml` configures generated passwords for the following secrets:

- App password (for the UI)
- System password for the OS system <virl_username>istration user
- Cluster secret when clustering is enabled

Regardless of the secret manager in use or whether you use random passwords or not:  You **must** provide a valid Smart Licensing token for the sytem to work, though.

##### CyberArk Conjur installation

> [!IMPORTANT]
> CyberArk Conjur is not currently in the Terraform Registry.  You must follow its [installation instructions](https://github.com/cyberark/terraform-provider-conjur?tab=readme-ov-file#terraform-provider-conjur) before running `terraform init`. 

These steps are only required if using CyberArk Conjur as an external secrets manager.
1. Download the [CyberArk Conjur provider](https://github.com/cyberark/terraform-provider-conjur/releases).
2. Copy the custom provider to `~/.terraform.d/plugins/localhost/cyberark/conjur/<version>/<architecture>/terraform-provider-conjur_v<version>`
   ```bash
   $ mkdir -vp ~/.terraform.d/plugins/localhost/cyberark/conjur/0.6.7/darwin_arm64/
   $ unzip ~/terraform-provider-conjur_0.6.7-4_darwin_arm64.zip -d ~/.terraform.d/plugins/localhost/cyberark/conjur/0.6.7/darwin_arm64/
   $
   ```
3. Create a `.terraformrc` file in the user's home:
   ```hcl
   provider_installation {
     filesystem_mirror {
       path    = "/Users/example/.terraform.d/plugins"
       include = ["localhost/cyberark/conjur"]
     }
     direct {
       exclude = ["localhost/cyberark/conjur"]
     }
   }
   ```

### Terraform installation

Terraform can be downloaded for free from [here](https://developer.hashicorp.com/terraform/downloads). This site has also instructions how to install it on various supported platforms.

Deployments of CML using Terraform were tested using the versions mentioned below on Ubuntu Linux and macOS.

```bash
$ terraform version
Terraform v1.8.0
on darwin_arm64
+ provider registry.terraform.io/ciscodevnet/cml2 v0.7.0
+ provider registry.terraform.io/hashicorp/aws v5.45.0
+ provider registry.terraform.io/hashicorp/azurerm v3.99.0
+ provider registry.terraform.io/hashicorp/cloudinit v2.3.3
+ provider registry.terraform.io/hashicorp/random v3.6.1
+ provider registry.terraform.io/hashicorp/vault v4.2.0
+ provider localhost/cyberark/conjur v0.6.7
$
```

It is assumed that the CML cloud repository was cloned to the computer where Terraform was installed. The following command are all executed within the directory that has the cloned repositories. In particular, this `README.md`, the `main.tf` and the `config.yml` files, amongst other files.

When installed, run `terraform init` to initialize Terraform. This will download the required providers and create the state files.

## Using sshuttle for VPN-like Access

To access your CML instance and its internal networks, you can use sshuttle as a lightweight VPN alternative. This allows you to reach the CML web interface and any nodes in your labs directly from your local machine.

### Installation

```bash
# On Ubuntu/Debian
sudo apt-get install sshuttle

# On macOS using Homebrew
brew install sshuttle

# Using pip (all platforms)
pip install sshuttle
```

### Basic Usage

To create a VPN-like connection to your CML instance:

```bash
# Replace 10.0.0.0/16 with your CML instance's internal network range
sshuttle --dns -r admin@your-cml-instance 10.0.0.0/16
```

### macOS Configuration

On macOS, you'll need additional configuration due to the platform's security features:

1. Copy the provided packet filter configuration:
   ```bash
   sudo cp extras/pf.sshuttle.conf /etc/pf.anchors/
   ```

2. Add the following line to `/etc/pf.conf` if it doesn't exist:
   ```
   rdr-anchor "sshuttle"
   ```

3. Load the configuration:
   ```bash
   sudo pfctl -f /etc/pf.conf
   ```

The `pf.sshuttle.conf` file is required on macOS because:
- macOS uses the Packet Filter (PF) firewall
- sshuttle needs specific firewall rules to forward traffic
- The configuration allows:
  - Traffic to the SSH tunnel port (2222)
  - Forwarded traffic to/from your CML networks
  - Proper NAT for return traffic

### Usage Tips

1. Run sshuttle in the background:
   ```bash
   sshuttle --dns -D -r admin@your-cml-instance 10.0.0.0/16
   ```

2. To stop the background process:
   ```bash
   pkill sshuttle
   ```

3. For AWS deployments, use the bastion host:
   ```bash
   sshuttle --dns -r admin@your-bastion-host 10.0.0.0/16
   ```

Once connected, you can:
- Access the CML web interface using its private IP
- Connect directly to nodes in your labs
- Use DNS resolution for lab hostnames

## Cloud specific instructions

See the documentation directory for cloud specific instructions:

- [Amazon Web Services (AWS)](documentation/AWS.md)
- [Microsoft Azure](documentation/Azure.md)

## Customization

There's two Terraform variables which can be defined / set to further customize the behavior of the tool chain:

- `cfg_file`: This variable defines the configuration file.  It defaults to `config.yml`.
- `cfg_extra_vars`: This variable defines the name of a file with additional variable definitions.  The default is "none".

```bash
export TF_VAR_access_key="aws-something"
export TF_VAR_secret_key="aws-somethingelse"

# export TF_VAR_subscription_id="azure-something"
# export TF_VAR_tenant_id="azure-something-else"

export TF_VAR_cfg_file="config-custom.yml"
export TF_VAR_cfg_extra_vars="extras.sh"
```

A typical extra vars file would look like this (as referenced by `extras.sh` in the code above):

```plain
CFG_UN="username"
CFG_PW="password"
CFG_HN="domainname"
CFG_EMAIL="noone@acme.com"
```

In this example, four additional variables are defined which can be used in customization scripts during deployment to provide data (usernames, passwords, ...) for specific services like configuring DNS.

See the AWS specific document for additional information how to define variables in the environment using tools like `direnv` ("Terraform variable definition").

## Additional customization scripts

The deploy module has a couple of extra scripts which are not enabled / used by default.  They are:

- request/install certificates from LetsEncrypt (`03-letsencrypt.sh`)
- customize additional settings, here: add users and resource pools (`04-customize.sh`).

These additional scripts serve mostly as an inspiration for customization of the system to adapt to local requirements.

### Requesting a cert

The letsencrypt script requests a cert if there's none already present.  The cert can then be manually copied from the host to the cloud storage with the hostname as a prefix.  If the host with the same hostname is started again at a later point in time and the cert files exist in cloud storage, then those files are simply copied back to the host without requesting a new certificate.  This avoids running into any certificate request limits.

Certificates are stored in `/etc/letsencrypt/live` in a directory with the configured hostname.

## Limitations

Extra variable definitions and additional scripts will all be stored in the user-data that is provided via cloud-init to the cloud host.  There's a limitation in size for the user-data in AWS.  The current limit is 16KB.  Azure has a much higher limit (unknown what the limit actually is, if any).

All scripts are copied as they are including all comments which will require even more space.

A potential solution to the data limit is to provide the scripts in storage by bundling them up into a tar file or similar, store the tar file in S3 and then only reference this file in the user-data.  However, this hasn't been implemented, yet.

## Development

### Git Hooks

This repository uses git hooks to maintain code quality:

- `pre-commit`: Automatically sanitizes configuration files to remove sensitive data
- `pre-push`: Prevents pushing sensitive files to public repositories

To enable the hooks:
```bash
git config core.hooksPath .githooks
chmod +x .githooks/*
```
