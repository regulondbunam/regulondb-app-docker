FROM --platform=linux/amd64 mongo:latest as mongo

ARG MONGO_INITDB_ROOT_USERNAME
ARG MONGO_INITDB_ROOT_PASSWORD

ENV MONGO_INITDB_ROOT_USERNAME=$MONGO_INITDB_ROOT_USERNAME
ENV MONGO_INITDB_ROOT_PASSWORD=$MONGO_INITDB_ROOT_PASSWORD

COPY /MongoDB/dump /dump
RUN chmod -R 777 /dump/
RUN chmod -R 777 /dump/regulondbdatamarts
COPY /MongoDB/init-db.d/seed.sh /docker-entrypoint-initdb.d/

FROM --platform=linux/amd64 node:15 as node

FROM node as graphql

WORKDIR /app

COPY /GraphQL-api/package.json /app
COPY /GraphQL-api/package-lock.json /app

RUN NODE_OPTIONS="--max-old-space-size=8192"
RUN npm i

COPY /GraphQL-api /app

RUN npm run build

ENTRYPOINT [ "npm", "start" ]

FROM node as react-build-stage

ARG API_URL

WORKDIR /RegulonDB-Browser

COPY /RegulonDB-Browser/package.json /RegulonDB-Browser/package.json
COPY /RegulonDB-Browser/package-lock.json /RegulonDB-Browser/package-lock.json

RUN NODE_OPTIONS="--max-old-space-size=8192"

RUN npm install

COPY /RegulonDB-Browser /RegulonDB-Browser

RUN echo '{ "graphQlUrl": "'$API_URL'" }' > src/webServices/apollo.conf.json

RUN npm run build

FROM node as webapp

WORKDIR RegulonDB-Browser

RUN npm install -g serve

COPY --from=react-build-stage /RegulonDB-Browser/build ./build

ENTRYPOINT ["serve", "-s", "build"]


FROM --platform=linux/amd64 nginx:stable-alpine as proxy

COPY proxy/nginx.conf /etc/nginx/conf.d/default.conf
