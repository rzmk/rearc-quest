# Rearc Quest

The following are notes/steps I took when exploring [rearc/quest](https://github.com/rearc/quest).

## Step 1

- Downloaded the rearc/quest git repository as a zip file and unzipped it.
- Made a separate directory for submitting work files (notes, etc.), initializing it as a git repository with `git init`.

## Step 2

- Launched an EC2 Instance on Amazon Linux 64-bit x86/64 as the OS on a t2.micro instance. I already have a private key `.pem` file so I'll be using it for when I use SSH.
- To access the EC2 instance through SSH, I used the following command `ssh -i /path/my-key-pair.pem my-instance-user-name@my-instance-public-dns-name` ([reference](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/AccessingInstancesLinux.html)) in my terminal, replacing `/path/my-key-pair.pem` with my actual `.pem` path, `my-instance-user-name` with `ec2-user` as the default user, and `my-instance-public-dns-name` with the instance's public IPv4 address.
- To upload the quest directory `quest-master` to the EC2 instance, I ran the command `scp -P 22 -r -i /path/my-key-pair.pem /path/my-directory ec2-user@my-instance-public-dns-name:~`.
  - `scp` is the secure copy protocol I used for transferring files from my local computer to the remote EC2 instance.
  - `-P 22` represents the port flag and port number that I should transfer to (default SSH port).
  - `-r` causes recursively copying the current directory ([reference](https://linux.die.net/man/1/scp)).
  - `-i /path/my-key-pair.pem` identifies the `.pem` file.
  - `:~` has the colon divide the remote username and host name with the directory to copy into, in this case the home directory.
- The `scp` transfer worked successfully but the directory in the EC2 instance seemed to retain the entire absolute path, so I used the `mv` command to rename it to simply `rearc-quest` ([reference](https://devconnected.com/how-to-rename-a-directory-on-linux/)).
- I need to test deploying the application, so I'll need to download node on the EC2 instance ([reference](https://docs.aws.amazon.com/sdk-for-javascript/v2/developer-guide/setting-up-node-on-ec2-instance.html)).
  - I followed the steps in the reference but when trying to install node, the latest version had issues so I installed a stable version 16 with `nvm install 16`. I was then able to run the node server with `node src/000.js`.
- So far when navigating to the index page from the EC2 instance's public DNS and port 3000, I get "/bin/sh: bin/001: Permission denied". I believe in step 4 I will be able to see the `SECRET_WORD` on the index page.
