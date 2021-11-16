FROM minio/minio:RELEASE.2021-02-14T04-01-33Z

RUN mkdir -p /usr/local/bin
RUN mv /usr/bin/docker-entrypoint.sh /usr/bin/docker-entrypoint-inner.sh

USER root

COPY .docker-tmp/consul /usr/bin/consul
COPY docker-entrypoint.sh /usr/bin/docker-entrypoint.sh
RUN chmod a+x /usr/bin/docker-entrypoint.sh
