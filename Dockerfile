FROM alpine:latest

# Install dependencies
RUN apk update && apk upgrade && \
    apk add --no-cache \
    build-base \
    sqlite-dev \
    zlib-dev \
    sqlite \
    bash \
    tzdata \
    ruby \
    ruby-dev

# Update RubyGems and install bundler
RUN gem update --system && \
    gem install bundler

# Create a directory for the app
WORKDIR /app

# Copy Gemfile first for better Docker layer caching
COPY Gemfile /app/

# Install gems
RUN bundle install --without test

# Copy the Ruby scripts into the container
COPY app/generate_hosts.rb /app/
COPY app/lib /app/lib

# Clean up
RUN rm -rf /var/cache/apk/* /tmp/* /usr/lib/ruby/gems/*/cache/*

# Set the entrypoint to the Ruby script
ENTRYPOINT ["ruby", "/app/generate_hosts.rb"]

# This will allow you to pass any additional arguments to the script
CMD []
