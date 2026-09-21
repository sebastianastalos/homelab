# Upstream publishes no image, so this is built on the host:
#   sudo docker build -t actual-flow:0.0.22 /mnt/app/actual-flow/build
# Both the base image and the package are pinned - upstream's own Dockerfile
# installs the package unpinned, which would drift on every rebuild.
FROM node:22.23.2-alpine

# tzdata: without it TZ is silently ignored and the container runs UTC.
# The uid 950 user exists so busybox crond can run the job as itself -
# as non-root it cannot setuid to a crontab named after another user.
RUN apk add --no-cache bash tini tzdata \
    && addgroup -g 950 actual \
    && adduser -D -u 950 -G actual actual \
    && npm install -g @lunchflow/actual-flow@0.0.22

# cover.js requires @actual-app/api, which is nested inside the globally
# installed package, so node needs pointing at it.
ENV NODE_PATH=/usr/local/lib/node_modules/@lunchflow/actual-flow/node_modules
COPY cover.js /usr/local/lib/cover.js
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod 755 /usr/local/bin/entrypoint.sh

WORKDIR /app/config
ENTRYPOINT ["/sbin/tini", "--"]
CMD ["/usr/local/bin/entrypoint.sh"]
