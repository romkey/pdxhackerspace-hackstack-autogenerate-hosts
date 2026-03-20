FROM ruby:3.2-alpine

# Install runtime dependencies and build deps in one layer
# Build native gems, then remove build dependencies to keep image small
RUN apk add --no-cache sqlite-libs tzdata && \
    apk add --no-cache --virtual .build-deps build-base sqlite-dev && \
    gem install sqlite3 --no-document && \
    apk del .build-deps && \
    rm -rf /root/.gem /usr/local/bundle/cache

WORKDIR /app

# Copy application files
COPY app/generate_hosts.rb /app/
COPY app/lib /app/lib

ENTRYPOINT ["ruby", "/app/generate_hosts.rb"]
CMD []
