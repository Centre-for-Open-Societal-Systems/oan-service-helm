# Demo data for one service, copied into the site-config job by an init container.
# docker build --build-arg SERVICE=<a2c|grievance> -t <repository>:<tag> seed
FROM busybox:1.36
ARG SERVICE
COPY ${SERVICE}/ /seed/
COPY load.py /seed/load.py
RUN chmod -R a+rX /seed
