FROM node:8

EXPOSE 3012

WORKDIR /opt/server

COPY . .

RUN yarn install
RUN npm install -g nodemon

CMD ["nodemon", "server.js"]
