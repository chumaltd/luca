FROM ruby:3.2-slim-bullseye
LABEL maintainer "LucaSuite dev team"

RUN apt-get update && apt-get install -y --no-install-recommends \
    git wkhtmltopdf \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

RUN gem install lucasuite lucaterm mail
