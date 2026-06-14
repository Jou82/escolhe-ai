FROM ruby:3.3.5

WORKDIR /app

# Instala Node.js e dependências do sistema
RUN apt-get update && \
  apt-get install -y curl && \
  curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && \
  apt-get install -y nodejs postgresql-client && \
  rm -rf /var/lib/apt/lists/*

COPY Gemfile Gemfile.lock ./
RUN bundle install

COPY . .

# Pré-compila assets sem precisar do banco de dados
RUN DISABLE_DATABASE_ENVIRONMENT_CHECK=1 bundle exec rails assets:precompile

EXPOSE 3000
CMD ["bin/rails", "server", "-b", "0.0.0.0"]
