FROM --platform=$BUILDPLATFORM node:18-alpine as builder

RUN apk add --no-cache jq bash coreutils python3 build-base

WORKDIR /app

COPY package.json yarn.lock /app/
COPY scripts /app/scripts
RUN yarn install

COPY public /app/public
COPY src /app/src
COPY index.html pwa-manifest.json tsconfig.json vite.config.ts /app/
RUN yarn build:deployment

FROM nginx:1.23.4-alpine as production

COPY --from=builder /app/dist /usr/share/nginx/html
COPY docker/funkwhale.conf.template /etc/nginx/templates/default.conf.template
COPY docker/funkwhale_proxy.conf /etc/nginx/funkwhale_proxy.conf
COPY docker/entrypoint.sh /docker-entrypoint.d/99-funkwhale.sh

# Allow running as non-root for custom setups
RUN mkdir -p /var/log/nginx /var/cache/nginx /var/run/nginx && \
    chown -R nginx:nginx /var/log/nginx /var/run/nginx /var/cache/nginx /etc/nginx && \
    sed -e 's#/var/run/nginx.pid#/var/run/nginx/nginx.pid#' -i /etc/nginx/nginx.conf

ENV FUNKWHALE_API_HOST=api
ENV FUNKWHALE_API_PORT=5000
