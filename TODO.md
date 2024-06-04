# TODO

Here's a list of things which should be implemented going forward.  This is in no particular order at the moment.

1. Allow for multiple instances in same account/resource group. Right now, resources do not have a unique name and they should.  Using the random provider as done with the AWS VPC already.
2. Allow cluster installs on Azure (AWS is working, see below).
3. Allow for certs to be pushed to cloud storage, once requested/installed.
4. Allow more than one clouds at the same time as `prepare.sh` suggests.  Right now, this does not work as it requires only ONE `required_providers` block but both template files introduce an individual one.  Should be addressed by making this smarter, introducing a `versions.tf` file which is built by `prepare.sh`.  See <https://discuss.hashicorp.com/t/best-provider-tf-versions-tf-placement/56581/5>

## Done items

1. Work around 16kb user data limit in AWS (seems to not be an issue in Azure).
2. Allow cluster installs (e.g. multiple computes, adding a VPC cluster network).  Works on AWS, thanks to amieczko.
3. Allow to use an already existing VPC
