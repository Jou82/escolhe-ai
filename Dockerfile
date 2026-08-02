FROM ruby:3.3.5

WORKDIR /app

RUN apt-get update && \
  apt-get install -y curl && \
  curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && \
  apt-get install -y nodejs postgresql-client && \
  rm -rf /var/lib/apt/lists/*

COPY Gemfile Gemfile.lock ./
RUN bundle install

COPY . .

# SECRET_KEY_BASE_DUMMY evita precisar de master.key durante o build
RUN RAILS_ENV=production SECRET_KEY_BASE_DUMMY=1 bundle exec rails assets:precompile

EXPOSE 3000
# Migrations run via railway.toml preDeployCommand. Puma reads PORT from env.
CMD ["bundle", "exec", "rails", "server", "-b", "0.0.0.0"]

# Note: db:seed is optional and can be run manually
# Rails will auto-create schema if needed via db:migrate
