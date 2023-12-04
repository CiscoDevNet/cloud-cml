# TODO

Here's a list of things which should be implemented going forward.  This is in no particular order at the moment.

1. Work around 16kb user data limit in AWS (seems to not be an issue in Azure).
1. Allow for multiple instances in same account/resource group. Right now, resources do not have a unique name and they should.  Using the random provider as done with the AWS VPC already.
2. Allow cluster installs (e.g. multiple computes, adding a VPC cluster network).  There *seems* to be an issue on AWS with IPv6 addressing which might make this impossible)
2. Allow for certs to be pushed to cloud storage, once requested/installed.

