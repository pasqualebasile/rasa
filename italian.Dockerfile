# if this installation process changes, the enterprise container needs to be
# updated as well
# Costruito a partire da ```docker/Docker_pretrained_embedding_spacy_en```
# ma utilizzato il corpus italiano
# Periodicamente controllare se ci sono modifiche nel file origine

# Create common base stage
FROM python:3.6-slim as base

# Create virtualenv to isolate builds
RUN python -m venv /build

# Install common libraries
RUN apt-get update -qq \
 && apt-get install -y --no-install-recommends \
    # required by psycopg2 at build and runtime
    libpq-dev \
     # required for health check
    curl \
 && apt-get autoremove -y

# Make sure we use the virtualenv
ENV PATH="/build/bin:$PATH"

# Stage to build and install everything
FROM base as builder

WORKDIR /src

# Questo era nella build precedente... per il momento solo commento
# COPY . .
# RUN python setup.py sdist bdist_wheel
# RUN find dist -maxdepth 1 -mindepth 1 -name '*.tar.gz' -print0 | xargs -0 -I {} mv {} rasa.tar.gz

RUN apt-get update -qq && \
  apt-get install -y --no-install-recommends \
  build-essential \
  wget \
  bash \
  nano \
  openssh-client \
  graphviz-dev \
  pkg-config \
  git-core \
  openssl \
  libssl-dev \
  libffi6 \
  libffi-dev \
  libpng-dev \
  libpq-dev \
  curl && \
  apt-get clean && \
  rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* && \
  mkdir /install && \
  mkdir /app

# Install spacy model
RUN pip install https://github.com/explosion/spacy-models/releases/download/it_core_news_sm-2.1.0/it_core_news_sm-2.1.0.tar.gz#egg=it_core_news_sm==2.1.0 --no-cache-dir > /dev/null \
    && python -m spacy link it_core_news_sm it

# Copy only what we really need
COPY README.md .
COPY setup.py .
COPY setup.cfg .
COPY MANIFEST.in .
COPY alt_requirements/ ./alt_requirements
COPY requirements.txt .

# Install Rasa and its dependencies
RUN pip install --no-cache-dir -r alt_requirements/requirements_pretrained_embeddings_spacy.txt

# Install Rasa as package
COPY rasa ./rasa
RUN pip install .[sql,spacy]

# Runtime stage which uses the virtualenv which we built in the previous stage
FROM base AS runner

# Su questa parte non sono tanto sicuro ... probabilmente va creato prima
# L'obiettivo è avere `/app` mappata all'esterno, ma non sono sicuro che funzioni così
VOLUME ["/app"]
WORKDIR /app

# Copy over default pipeline config
COPY sample_configs/config_pretrained_embeddings_spacy.yml config.yml

# Copy virtualenv from previous stage
COPY --from=builder /build /build

# Create a volume for temporary data
VOLUME /tmp

# Make sure the default group has the same permissions as the owner
RUN chgrp -R 0 . && chmod -R g=u .

# Don't run as root
USER 1001

EXPOSE 5005

ENTRYPOINT ["rasa"]
CMD ["--help"]
