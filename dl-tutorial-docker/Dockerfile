FROM jupyter/pyspark-notebook

MAINTAINER christian@svds.com

RUN conda install --quiet --yes keras tensorflow

COPY images/ work/images/
COPY vgg_demo_v4.ipynb work/dl-tutorial.ipynb
COPY data/ work/data/

USER root
RUN chown -R jovyan work/
USER jovyan
