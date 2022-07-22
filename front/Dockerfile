FROM node:16-alpine as builder

WORKDIR /app
COPY package.json yarn.lock /app/
COPY src /app/src/
COPY scripts /app/scripts
COPY public /app/public
COPY vite.config.js index.html embed.html /app/

RUN apk add --no-cache jq bash coreutils python3 build-base
RUN yarn install
RUN yarn build:deployment


FROM nginx:1.23.1-alpine as final

COPY --from=builder /app/dist /usr/share/nginx/html
COPY docker/funkwhale.template /etc/nginx/conf.d/funkwhale.template
COPY docker/funkwhale_proxy.conf /etc/nginx/funkwhale_proxy.conf

# Allow running as non-root for custom setups
RUN mkdir -p /var/log/nginx /var/cache/nginx /var/run/nginx && \
    chown -R nginx:nginx /var/log/nginx /var/run/nginx /var/cache/nginx /etc/nginx && \
    sed -e 's#/var/run/nginx.pid#/var/run/nginx/nginx.pid#' -i /etc/nginx/nginx.conf

CMD ["sh", "-c", "envsubst \"`env | awk -F = '{printf \" $$%s\", $$1}'`\" \
        < /etc/nginx/conf.d/funkwhale.template \
        > /etc/nginx/conf.d/default.conf \
        && cat /etc/nginx/conf.d/default.conf \
        && nginx -g 'daemon off;'"]

ENV FUNKWHALE_API_HOST=api
ENV FUNKWHALE_API_PORT=5000
ENV AWS_S3_ENDPOINT_URL=
