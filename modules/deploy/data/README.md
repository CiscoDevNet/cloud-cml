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

