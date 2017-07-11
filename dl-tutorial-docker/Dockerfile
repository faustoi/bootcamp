FROM jupyter/pyspark-notebook

MAINTAINER christian@svds.com

RUN conda install -n python2 --quiet --yes mkl-service keras tensorflow

WORKDIR /home/jovyan/work
COPY create_sets.py create_sets.py
RUN wget https://download.microsoft.com/download/3/E/1/3E1C3F21-ECDB-4869-8368-6DEBA77B919F/kagglecatsanddogs_3367a.zip -o download.log -O cats-dogs.zip \
    && python create_sets.py cats-dogs.zip

COPY images/ images/
COPY vgg_demo_v4.ipynb dl-tutorial.ipynb

USER root
RUN chown -R jovyan ./
USER jovyan
