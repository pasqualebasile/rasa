FROM python:3.6-slim as builder
# if this installation process changes, the enterprise container needs to be
# updated as well
# Costruito a partire da Docker_pretrained_embedding_spacy_en 
#  ma utilizzato il corpus italiano

WORKDIR /build
COPY . .
RUN python setup.py sdist bdist_wheel
RUN find dist -maxdepth 1 -mindepth 1 -name '*.tar.gz' -print0 | xargs -0 -I {} mv {} rasa.tar.gz

FROM python:3.6-slim

SHELL ["/bin/bash", "-c"]

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

WORKDIR /install

# Copy as early as possible so we can cache ...
COPY alt_requirements/ ./alt_requirements
COPY requirements.txt .

RUN pip install -r alt_requirements/requirements_pretrained_embeddings_spacy.txt

COPY --from=builder /build/rasa.tar.gz .
RUN pip install ./rasa.tar.gz[sql,spacy]

RUN pip install https://github.com/explosion/spacy-models/releases/download/it_core_news_sm-2.1.0/it_core_news_sm-2.1.0.tar.gz#egg=it_core_news_sm==2.1.0 --no-cache-dir > /dev/null \
    && python -m spacy link it_core_news_sm it

COPY sample_configs/config_pretrained_embeddings_spacy.yml /app/config.yml

VOLUME ["/app"]
WORKDIR /app

EXPOSE 5005

ENTRYPOINT ["rasa"]

CMD ["--help"]
