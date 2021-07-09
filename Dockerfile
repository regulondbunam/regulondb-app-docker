FROM node:alpine as node

FROM node as graphql

WORKDIR /app

COPY /GraphQL-api/package*.json /app

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

WORKDIR RegulonDB-Browser

RUN npm install -g serve

COPY --from=react-build-stage /RegulonDB-Browser/build ./build

ENTRYPOINT ["serve", "-s", "build"]


FROM nginx:stable-alpine as proxy

COPY proxy/nginx.conf /etc/nginx/conf.d/default.conf
