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

FROM node:alpine as runner
WORKDIR /app/
COPY --from=server_builder /build/ .
COPY ./apps/clients ./clients

ENV NODE_ENV=production
ENV PORT=7541
ENV URL="http://localhost:7541"
ENV DATABASE_FILE="file:/data/database.db"

CMD ["sh", "-c", "yarn prisma db push --skip-generate && node apps/server/dist/server.js"]
