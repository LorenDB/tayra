FROM node:16-buster

# needed to compile translations
RUN apt-get update && apt-get install -y jq

EXPOSE 8080
WORKDIR /app/
COPY scripts/ ./scripts/
ADD package.json yarn.lock  ./
RUN yarn install

COPY . .

CMD ["yarn", "serve"]
