FROM node:latest as server_builder
WORKDIR /app/
RUN yarn global add turbo
COPY . .
RUN turbo prune server --docker

WORKDIR /build/
RUN cp -r /app/out/json/* .
RUN yarn install
RUN cp -r /app/out/full/* .
RUN turbo build --filter=server
RUN yarn install --production

FROM gcr.io/distroless/nodejs20-debian11 as runner
WORKDIR /app/
COPY --from=server_builder /build/ .
COPY ./apps/clients ./clients

ENV NODE_ENV=production
ENV PORT=7541
ENV URL="http://localhost:7541"
ENV DATABASE_URL="file:/data/database.db"

VOLUME [ "/data" ]

CMD ["apps/server/dist/server.js"]
