FROM node:8

WORKDIR /opt/server

RUN yarn install
RUN npm install -g nodemon

CMD ["nodemon", "server.js"]