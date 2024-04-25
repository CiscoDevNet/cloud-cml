# Copy file behavior

Azure copy and AWS CLI cp in recursive mode apparently behave different. While Azure takes the directory name into account, it seems like AWS does not.

Example:

cp --recursive srcdir/ dstdir/

Using Azure, the result will be (as expected):

```
dstdir/srcdir/file1
             /file
```

while with AWS, it's unfortunately:

```
dstdir/file1
      /file2
```

So, to make this work, the logic needs to add the srcdir to the dstdir but only when copying files on AWS, not on Azure.  This is done in `copyfile.sh` with the `$ITEM` arg in case anyone is wondering.

Not adding this lengthy comment to the file itself due to the 16KB cloud-init limitation on AWS.

## Service restart

The cml.sh script post processing function originally stopped the target, ran through all the patches and then restarted the target at the end.  However, some scripts might require the target to be running (to provision users, for example) while others might change something that does not require a full target restart.  For this reason, I've removed the logic for stop/start of the target from post processing and moved it here for reference.  If multiple scripts would require a stop/start, then it would be advised to indicate the restart requirement with a flag (e.g. a file flag or something) which then could be checked at the end of post processing.  If present, services will be restarted.

```bash
# systemctl stop virl2.target
# while [ $(systemctl is-active virl2-controller.service) = active ]; do
#     sleep 5
# done

# sleep 5
# # do this for good measure, best case this is a no-op
# netplan apply
# # restart the VIRL2 target now
# systemctl restart virl2.target
```
