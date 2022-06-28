FROM node:16 as builder
WORKDIR /app
COPY package.json yarn.lock /app/
COPY src /app/src/
COPY scripts /app/scripts
COPY public /app/public
COPY vite.config.js index.html embed.html /app/

RUN yarn install
RUN yarn build:deployment

FROM nginx:1.21.6-alpine as final
COPY --from=builder /app/dist /usr/share/nginx/html
COPY docker/funkwhale.template /etc/nginx/conf.d/funkwhale.template
COPY docker/funkwhale_proxy.conf /etc/nginx/funkwhale_proxy.conf
