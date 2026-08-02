FROM ruby:3.3.5

WORKDIR /app

# Single-service Railway deploy: run Solid Queue inside Puma so
# GenerateRecommendationsJob actually executes (otherwise the UI
# stays forever on /movies/processing).
ENV SOLID_QUEUE_IN_PUMA=true

RUN apt-get update && \
  apt-get install -y curl && \
  curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && \
  apt-get install -y nodejs postgresql-client && \
  rm -rf /var/lib/apt/lists/* && \
  groupadd --system --gid 1000 rails && \
  useradd rails --uid 1000 --gid 1000 --create-home --shell /bin/bash

COPY Gemfile Gemfile.lock ./
RUN bundle install

COPY . .

# SECRET_KEY_BASE_DUMMY evita precisar de master.key durante o build
RUN RAILS_ENV=production SECRET_KEY_BASE_DUMMY=1 bundle exec rails assets:precompile \
  && mkdir -p tmp/pids tmp/cache log \
  && chown -R rails:rails /app

USER rails

EXPOSE 3000
CMD ["sh", "-c", "bundle exec rails db:migrate && bundle exec rails server -b 0.0.0.0 -p ${PORT:-3000}"]
