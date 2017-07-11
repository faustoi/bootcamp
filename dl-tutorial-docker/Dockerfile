FROM jupyter/pyspark-notebook

MAINTAINER christian@svds.com

RUN conda install --quiet --yes keras tensorflow

WORKDIR work
RUN curl https://download.microsoft.com/download/3/E/1/3E1C3F21-ECDB-4869-8368-6DEBA77B919F/kagglecatsanddogs_3367a.zip > cats-dogs.zip
    && python create_sets.py cats-dogs.zip

COPY images/ images/
COPY vgg_demo_v4.ipynb work/dl-tutorial.ipynb

USER root
RUN chown -R jovyan ./
USER jovyan
