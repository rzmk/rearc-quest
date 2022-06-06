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