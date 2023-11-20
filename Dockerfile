FROM debian:bookworm-20231030-slim
ARG PROJECT_NAME=hord_watcher
ARG USERNAME=watcher
ARG USER_UID=1520
ARG USER_GID=$USER_UID
COPY target/release/${PROJECT_NAME} /app/${PROJECT_NAME}
RUN groupadd --gid $USER_GID $USERNAME \
 && useradd --uid $USER_UID --gid $USER_GID -m $USERNAME
USER $USERNAME
EXPOSE 3000

ENTRYPOINT [ "/app/hord_watcher" ]
