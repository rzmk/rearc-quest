#!bin/bash
sudo yum -y update && sudo yum -y install git
sudo amazon-linux-extras install docker -y
sudo service docker start
git clone https://github.com/rearc/quest.git
cd quest
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.34.0/install.sh | bash
. ~/.nvm/nvm.sh
npm i
touch Dockerfile
cat > Dockerfile << EOF
# node base image
FROM node:16

# environment variables
ENV SECRET_WORD    TwelveFactor

COPY . .

# setup and installation commands
RUN curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.34.0/install.sh | bash \
    && . ~/.nvm/nvm.sh \
    && nvm install 16 \
    && npm install

# run express server
CMD ["npm", "start"]
EOF
sudo docker build -t rearc-quest .
sudo docker run -d -p 80:3000 rearc-quest
sudo docker run -d -p 443:3000 rearc-quest
sudo docker run -d -p 3000:3000 rearc-quest
