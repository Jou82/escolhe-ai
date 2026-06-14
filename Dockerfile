FROM ruby:3.3-slim

WORKDIR /app

RUN apt-get update && apt-get install -y \
  build-essential \
  postgresql-client \
  git \
  && rm -rf /var/lib/apt/lists/*

COPY Gemfile Gemfile.lock ./

RUN bundle install

COPY . .

RUN bundle exec rails assets:precompile

EXPOSE 3000

CMD ["bin/rails", "server", "-b", "0.0.0.0"]
