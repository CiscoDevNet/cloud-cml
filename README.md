# README

Version 0.2.0, February 22 2024

This repository includes scripts, tooling and documentation to provision an instance of Cisco Modeling Labs (CML) in various cloud services. Currently supported are Amazon Web Services (AWS) and Microsoft Azure.

> **IMPORTANT** The CML deployment procedure and the tool chain / code provided in this repository are **considered "experimental"**. If you encounter any errors or problems that might be related to the code in this repository then please open an issue on the [Github issue tracker for this repository](https://github.com/CiscoDevNet/cloud-cml/issues).

## General requirements

The tooling uses Terraform to deploy CML instances in the Cloud. It's therefore required to have a functional Terraform installation on the computer where this tool chain should be used.

Furthermore, the user needs to have access to the cloud service. E.g. credentials and permissions are needed to create and modify the required resources. Required resources are

- service accounts
- storage services
- compute and networking services

The tool chain / build scripts and Terraform can be installed on the on-prem CML controller or, when this is undesirable due to support concerns, on a separate Linux instance.

That said, it *should be possible* to run the tooling also on macOS with tools installed via [Homebrew](https://brew.sh/). Or on Windows with WSL. However, this hasn't been tested by us.

### Preparation

Some of the steps and procedures outlined below are preparation steps and only need to be done once. Those are

- cloning of the repository
- installation of software (Terraform, cloud provider CLI tooling)
- creating and configuring of a service account, including the creation of associated access credentials
- creating the storage resources and uploading images and software into it
- creation of an SSH key pair and making the public key available to the cloud service
- editing the `config.yml` configuration file including the selection of the cloud service, an instance flavor, region, license token and other parameters

### Terraform installation

Terraform can be downloaded for free from [here](https://developer.hashicorp.com/terraform/downloads). This site has also instructions how to install it on various supported platforms.

Deployments of CML using Terraform were tested using the versions mentioned below on Ubuntu Linux.

```plain
$ terraform version
Terraform v1.7.3
on linux_amd64
+ provider registry.terraform.io/ciscodevnet/cml2 v0.7.0
+ provider registry.terraform.io/hashicorp/aws v5.37.0
+ provider registry.terraform.io/hashicorp/azurerm v3.92.0
+ provider registry.terraform.io/hashicorp/random v3.6.0
$
```

It is assumed that the CML cloud repository was cloned to the computer where Terraform was installed. The following command are all executed within the directory that has the cloned repositories. In particular, this `README.md`, the `main.tf` and the `config.yml` files, amongst other files.

When installed, run `terraform init` to initialize Terraform. This will download the required providers and create the state files.

## Cloud specific instructions

See the documentation directory for cloud specific instructions:

- [Amazon Web Services (AWS)](documentation/AWS.md)
- [Microsoft Azure](documentation/Azure.md)

## Customization

There's two variables which can be defined / set to further customize the behavior of the tool chain:

- `cfg_file`: This variable defines the configuration file.  It defaults to `config.yml`.
- `cfg_extra_vars`: This variable defines the name of a file with additional variable definitions.  The default is "none".

A typical extra vars file would look like this:

```plain
CFG_UN="username"
CFG_PW="password"
CFG_HN="domainname"
CFG_EMAIL="noone@acme.com"
```

In this example, four additional variables are defined which can be used in customization scripts during deployment to provide data (usernames, passwords, ...) for specific services like configuring DNS.

See the AWS specific document for additional information how to define variables in the environment using tools like `direnv` ("Terraform variable definition").

## Extra scripts

The deploy module has a couple of extra scripts which are not enabled / used by default.  They are:

- install IOL related files, likely obsolete with the release of 2.7 (`02-iol.sh`)
- request/install certificates from Letsencrypt (`03-letsencrypt.sh`)
- customize additional settings, here: add users and resource pools (`04-customize.sh`).

These additional scripts serve mostly as an inspiration for customization of the system to adapt to local requirements.

### Requesting a cert

The letencrypt script requests a cert if there's none already present.  The cert can then be manually copied from the host to the cloud storage with the hostname as a prefix.  If the host with the same hostname is started again at a later point in time and the cert files exist in cloud storage, then those files are simply copied back to the host without requesting a new certificate.  This avoids running into any certificate request limits.

Certificates are stored in `/etc/letsencrypt/live` in a directory with the configured hostname.

## Limitations

Extra variable definitions and additional scripts will all be stored in the user-data that is provided via cloud-init to the cloud host.  There's a limitation in size for the user-data in AWS.  The current limit is 16KB.  Azure has a much higher limit (unknown what the limit actually is, if any).

All scripts are copied as they are including all comments which will require even more space.

A potential solution to the data limit is to provide the scripts in storage by bundling them up into a tar file or similar, store the tar file in S3 and then only reference this file in the user-data.  However, this hasn't been implemented, yet.

EOF
