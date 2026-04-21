FROM ruby:3.3-slim

ENV APP_HOME=/rails \
    BUNDLE_JOBS=4 \
    BUNDLE_RETRY=3 \
    LANG=C.UTF-8

WORKDIR $APP_HOME

RUN apt-get update -qq \
    && apt-get install -y --no-install-recommends \
      build-essential \
      curl \
      ffmpeg \
      git \
      libpq-dev \
      libvips \
      libyaml-dev \
      postgresql-client \
      pkg-config \
    && rm -rf /var/lib/apt/lists/*

COPY Gemfile* ./

RUN bundle install

COPY . .

RUN chmod +x bin/*

RUN SECRET_KEY_BASE_DUMMY=1 \
    DATABASE_URL=postgresql://postgres:postgres@127.0.0.1:5432/permanent_underclass_build \
    RAILS_ENV=production \
    bundle exec rails assets:precompile

EXPOSE 3000

CMD ["bundle", "exec", "puma", "-C", "config/puma.rb"]
