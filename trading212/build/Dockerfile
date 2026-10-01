# Built on the host - there is no upstream image for this:
#   sudo docker build -t trading212-sync:1.0.0 /mnt/app/trading212/build
# @actual-app/api must match the Actual server version or downloadBudget fails
# with out-of-sync-migrations. tzdata and the uid 950 user mirror actual-flow.
FROM node:22.23.3-alpine

RUN apk add --no-cache bash tini tzdata \
    && addgroup -g 950 actual \
    && adduser -D -u 950 -G actual actual \
    && npm install -g @actual-app/api@26.9.0

COPY sync.js /usr/local/lib/sync.js
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod 755 /usr/local/bin/entrypoint.sh

ENV NODE_PATH=/usr/local/lib/node_modules
WORKDIR /app/data
ENTRYPOINT ["/sbin/tini", "--"]
CMD ["/usr/local/bin/entrypoint.sh"]
