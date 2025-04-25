FROM ruby:2.6.3

# Install required packages
RUN apt-get update && \
    apt-get install -y build-essential libsqlite3-dev sqlite3 git openssh-client && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# Configure bundler
ENV BUNDLE_JOBS=4
ENV BUNDLE_RETRY=3
ENV BUNDLE_PATH=/app/vendor/bundle
ENV BUNDLE_APP_CONFIG=/app/.bundle

# Don't run bundle install during build - we'll do it at runtime
# when the full codebase is mounted as a volume

CMD ["bash"] 