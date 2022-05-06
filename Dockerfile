FROM --platform=linux/amd64 mongo:4.4 as mongo

RUN mkdir -p /data/regulondbdatamarts \
    && echo "dbpath = /data/regulondbdatamarts" > /etc/mongodb.conf \
    && chown -R mongodb:mongodb /data/regulondbdatamarts

COPY /mongodb-datamarts/dump /data/dump

RUN chmod -R 777 /data/dump

RUN apt-get update \
 && apt-get install -y unzip

RUN unzip -q /data/dump/regulondbht/geneExpression.bson.zip -d /data/dump/regulondbht/

RUN mongod --fork --logpath /var/log/mongodb.log --dbpath /data/regulondbdatamarts \
    && mongorestore /data/dump \
    && mongo admin --eval "db.createUser({user: 'regulondbadmin', pwd: 'regulondb', roles: [{role: 'readWrite', db: 'regulondbdatamarts'}, {role: 'dbAdmin', db: 'regulondbdatamarts'}, {role: 'readWrite', db: 'regulondbht'}, {role: 'dbAdmin', db: 'regulondbht'}]});" \
    && mongod --dbpath /data/regulondbdatamarts --shutdown \
    && chown -R mongodb /data/regulondbdatamarts

# Make the new dir a VOLUME to persists it
VOLUME /data/regulondbdatamarts

CMD ["mongod", "--config", "/etc/mongodb.conf"]

FROM --platform=linux/amd64 node:16 as node

FROM node as graphql-dm

WORKDIR /app

COPY /GraphQL-api/package.json /app
COPY /GraphQL-api/package-lock.json /app

RUN npm i

COPY /GraphQL-api /app

ENTRYPOINT [ "npm", "start" ]

FROM node as graphql-ht

WORKDIR /app

COPY /RegulonDBHT-API/package.json /app
COPY /RegulonDBHT-API/package-lock.json /app

RUN npm i

COPY /RegulonDBHT-API /app

ENTRYPOINT [ "npm", "start" ]

FROM node as react-build-stage

ARG API_URL

ARG FLASK_URL

WORKDIR /RegulonDB-Browser

COPY /RegulonDB-Browser/package.json /RegulonDB-Browser/package.json
COPY /RegulonDB-Browser/package-lock.json /RegulonDB-Browser/package-lock.json

RUN npm install

COPY /RegulonDB-Browser /RegulonDB-Browser

ENV REACT_APP_WEB_SERVICE_URL=$API_URL

ENV REACT_APP_PROSSES_SERVICE=$FLASK_URL

RUN npm run build

FROM node as webapp

WORKDIR /RegulonDB-Browser

RUN npm install -g serve

COPY --from=react-build-stage /RegulonDB-Browser/build ./build

ENTRYPOINT ["serve", "-s", "build"]

ENV NODE_OPTIONS=--max_old_space_size=4096

FROM --platform=linux/amd64 nginx:stable-alpine as proxy

COPY proxy/nginx.conf /etc/nginx/conf.d/default.conf

FROM --platform=linux/amd64 ubuntu:18.04 as flask_app

ARG API_URL

RUN apt-get update \
 && apt-get install -y python3.7 \
 python3-pip

RUN python3.7 -m pip install pip

RUN apt-get update && \
 apt-get install -y python3.distutils \
 python3-setuptools

RUN python3.7 -m pip install pip --upgrade pip

RUN mkdir /app
WORKDIR /app
COPY regulonDB-wdpservice /app

RUN pip3 install Flask \
 && pip3 install pysftp \
 && pip3 install flask-cors \
 && pip3 install sgqlc \
 && pip3 install python-dotenv \
 && pip3 install pyopenssl

ENV FLASK_APP='app.py'
ENV FLASK_ENV=development
ENV GQL_SERVICE='http://datamartsApi:4000/graphql'

CMD flask run --host=0.0.0.0