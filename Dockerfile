
FROM ruby:3.2.2-slim

RUN apt-get update -qq && apt-get install -y \
  build-essential libpq-dev nodejs npm \
  libvips git curl libyaml-dev postgresql-client \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Gems
COPY Gemfile Gemfile.lock ./
RUN bundle install

# Node (para tailwind/esbuild si lo usas)
COPY package.json package-lock.json* yarn.lock* ./
RUN if [ -f package.json ]; then npm install; fi

COPY . .

# Entrypoint
COPY ./entrypoint.sh /usr/bin/entrypoint.sh
RUN chmod +x /usr/bin/entrypoint.sh
ENTRYPOINT ["entrypoint.sh"]

EXPOSE 3000
CMD ["bin/rails", "server", "-b", "0.0.0.0", "-p", "3000"]