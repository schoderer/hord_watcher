FROM alpine:3.18.4
ARG PROJECT_NAME=hord_watcher
COPY target/release/${PROJECT_NAME} /app/${PROJECT_NAME}
RUN adduser watcher
USER watcher
EXPOSE 3000

ENTRYPOINT [ "/app/hord_watcher" ]
