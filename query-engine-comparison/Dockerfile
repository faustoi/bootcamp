FROM cloudera/quickstart

WORKDIR /scripts

COPY *.sql ./
COPY *.sh ./
COPY *.py ./

EXPOSE 80 4040 7180 8888 10000

ENTRYPOINT exec /scripts/setup.sh
