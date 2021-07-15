FROM --platform=linux/amd64 mongo:4.4 as mongo

RUN mkdir -p /data/regulondbdatamarts \
    && echo "dbpath = /data/regulondbdatamarts" > /etc/mongodb.conf \
    && chown -R mongodb:mongodb /data/regulondbdatamarts

COPY /MongoDB/dump /data/dump
RUN chmod -R 777 /data/dump

RUN mongod --fork --logpath /var/log/mongodb.log --dbpath /data/regulondbdatamarts \
    && mongorestore /data/dump \
    && mongo admin --eval "db.createUser({user: 'regulondbdatamarts', pwd: 'regulondbdatamarts', roles: [{role: 'readWrite', db: 'regulondbdatamarts'}, {role: 'dbAdmin', db: 'regulondbdatamarts'}]});" \
    && mongod --dbpath /data/regulondbdatamarts --shutdown \
    && chown -R mongodb /data/regulondbdatamarts

# Make the new dir a VOLUME to persists it
VOLUME /data/regulondbdatamarts

CMD ["mongod", "--config", "/etc/mongodb.conf"]

FROM --platform=linux/amd64 node:15 as node

FROM node as graphql

WORKDIR /app

COPY /GraphQL-api/package.json /app
COPY /GraphQL-api/package-lock.json /app

RUN npm i

COPY /GraphQL-api /app

RUN npm run build

ENTRYPOINT [ "npm", "start" ]

FROM node as react-build-stage

ARG API_URL

WORKDIR /RegulonDB-Browser

COPY /RegulonDB-Browser/package.json /RegulonDB-Browser/package.json
COPY /RegulonDB-Browser/package-lock.json /RegulonDB-Browser/package-lock.json

RUN npm install

COPY /RegulonDB-Browser /RegulonDB-Browser

RUN echo '{ "graphQlUrl": "'$API_URL'" }' > src/webServices/apollo.conf.json

RUN npm run build

FROM node as webapp

WORKDIR /RegulonDB-Browser

RUN npm install -g serve

COPY --from=react-build-stage /RegulonDB-Browser/build ./build

ENTRYPOINT ["serve", "-s", "build"]


FROM --platform=linux/amd64 nginx:stable-alpine as proxy

COPY proxy/nginx.conf /etc/nginx/conf.d/default.conf
