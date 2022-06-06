# Rearc Quest

The following are notes/steps I took when exploring [rearc/quest](https://github.com/rearc/quest). Note that I'm new to some of these technologies and procedures, and that some of these notes may be over-detailed but were useful for my reference while exploring the quest.

## Step 1

> If you know how to use git, start a git repository (local-only is acceptable) and commit all of your work to it.

- Downloaded the rearc/quest git repository as a zip file and unzipped it.
- Made a separate directory for submitting work files (notes, etc.), initializing it as a git repository with `git init`.

## Step 2

**Note:** This step documents me applying the initial idea I had for transferring the repository files to the EC2 instance through `scp` and Linux file permissions. I noted in step 6 that I can simply install git and clone the repository, which is now my preferred method. I don't need to modify file permissions with this method, but this was a good learning experience.

> Deploy the app in any public cloud and navigate to the index page. Use Linux 64-bit x86/64 as your OS (Amazon Linux preferred in AWS, Similar Linux flavor preferred in GCP and Azure)

- Launched an EC2 Instance on Amazon Linux 2 64-bit x86/64 as the OS on a t2.micro instance. I already have a private key `.pem` file so I'll be using it for when I use SSH.
- To access the EC2 instance through SSH, I used the following command `ssh -i /path/my-key-pair.pem my-instance-user-name@my-instance-public-dns-name` ([reference](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/AccessingInstancesLinux.html)) in my terminal, replacing `/path/my-key-pair.pem` with my actual `.pem` path, `my-instance-user-name` with `ec2-user` as the default user, and `my-instance-public-dns-name` with the instance's public IPv4 address.
- To upload the quest directory `quest-master` to the EC2 instance, I ran the command `scp -P 22 -r -i /path/my-key-pair.pem /path/my-directory ec2-user@my-instance-public-dns-name:~`.
  - `scp` is the secure copy protocol I used for transferring files from my local computer to the remote EC2 instance.
  - `-P 22` represents the port flag and port number that I should transfer to (default SSH port).
  - `-r` causes recursively copying the current directory ([reference](https://linux.die.net/man/1/scp)).
  - `-i /path/my-key-pair.pem` identifies the `.pem` file.
  - `:~` has the colon divide the remote username and host name with the directory to copy into, in this case the home directory.
- The `scp` transfer worked successfully but the directory in the EC2 instance seemed to retain the entire absolute path, so I used the `mv` command to rename it to simply `rearc-quest` ([reference](https://devconnected.com/how-to-rename-a-directory-on-linux/)).
- I need to test deploying the application, so I'll need to download node on the EC2 instance ([reference](https://docs.aws.amazon.com/sdk-for-javascript/v2/developer-guide/setting-up-node-on-ec2-instance.html)).
  - I followed the steps in the reference but when trying to install node. First I used `curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.34.0/install.sh | bash` to install `nvm`, activated `nvm` with `. ~/.nvm/nvm.sh`, and then tried to install node with `nvm install node`. However, the latest version had issues so I installed a stable version 16 with `nvm install 16`. I then installed express with `npm i` and ran the node server with `npm start`.
- I edited the inbound rules for the security group that the EC2 instance is connected to, allowing incoming traffic to connect through port 3000 (the port the Rearc quest is running on).
- At first when navigating to the index page from the EC2 instance's public DNS and port 3000, I get "/bin/sh: bin/001: Permission denied". I googled a bit and learned that the "Permission denied" error can occur when the script/executable I'm trying to run doesn't have permissions to execute. I checked this by using `cd bin` and then `ls -l` to list all permissions for the executable files in `/bin`. Sure enough they didn't have execute permissions, so I used `chmod u+x 001` to allow execution and test the index page and it worked out. I found the secret word and a Yoda GIF. [This reference](https://www.shells.com/l/en-US/tutorial/How-to-Fix-Shell-Script-Permission-Denied-Error-in-Linux) helped me understand how to modify the file permissions, and I enabled execution for the rest of the `/bin` files.
- It also seems that I can't use HTTPS but HTTP produces results. I get a "This site can't provide a secure connection" error page when trying to access the public DNS on port 3000 with HTTPS. I assume step 7 may resolve this matter.

## Step 3

> Deploy the app in a Docker container. Use `node` as the base image. Version `node:10` or later should work.

- I learned some Docker concepts from ZeroToMastery Academy's first [Devops course](https://zerotomastery.io/courses/devops-bootcamp/) and Dockerfile commands (`FROM`, `ENV`, `COPY`, `RUN`, `EXPOSE`, `CMD`).
- I installed Docker on the server and began working on the Dockerfile ([reference](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/create-container-image.html)).
- I added a Dockerfile and configured it accordingly using a base `node` image of node version 16.
- I ran `docker run -d -p 80:3000 rearc-quest` ([reference to understand port mapping](https://docs.docker.com/engine/reference/commandline/run/))
  - `-d` allows the container to run in the background
  - `-p` allows the container port 3000 (since the node app runs on port 3000) to run on host port 80

## Step 4

> Inject an environment variable (`SECRET_WORD`) in the Docker container. The value of `SECRET_WORD` should be the secret word discovered on the index page of the application.

- I have different methods available to adding environment variables to the container. For now I will add the secret word to the Dockerfile with the `ENV` keyword, though using a `.env` file or within the run command with a `-e` flag may be more secure. The secret word shows up on the index page regardless so I won't worry about this.

## Step 5

> Deploy a load balancer in front of the app.

- Deployed an application load balancer through the AWS management console. I had to add a listener for port 80 and 443 so that end users can access the web page from HTTP or HTTPS.
- Pointed listeners to a target group that forwards traffic to port 3000 on the EC2 instance so that end users go to the running container application.

## Step 6

> Use Infrastructure as Code (IaC) to "codify" your deployment. Terraform is ideal, but use whatever you know, e.g. CloudFormation, CDK, Deployment Manager, etc.

- Learned how to setup basic infrastructure using Terraform from [a ZeroToMastery course](https://zerotomastery.io/courses/learn-terraform-certification/), completing 54% of the course before developing the quest IaC.
- Included a bash script that uses git to clone quest files and sets up a Dockerfile for Docker image creation and running containers.
- Included step 7 with [self-signed TLS certificate](https://registry.terraform.io/providers/hashicorp/tls/latest/docs/resources/self_signed_cert) generation in Terraform code.

## Step 7

> Add TLS (https). You may use locally-generated certs.

- Experimented with generating a self-signed certificate and registering it with Amazon Certificate Manager for allowing secure HTTPS connections to the application.
- Used the [TLS provider](https://registry.terraform.io/providers/hashicorp/tls/latest/docs) to add self-signed certificates for HTTPS connections with Terraform.
- I get a "This Connection is Not Private" warning before going to the page due to the certificate being self-signed.
