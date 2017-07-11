#!/usr/bin/env python3

from glob import glob
from shutil import copy
import sys
import os
from urllib.request import urlretrieve
import zipfile

FILE = 'cats-dogs.zip'
if not os.path.exists(FILE):
    print('Downloading data...')
    urlretrieve('https://download.microsoft.com/download/3/E/1/3E1C3F21-ECDB-4869-8368-6DEBA77B919F/kagglecatsanddogs_3367a.zip',
                FILE)

if not os.path.exists('data'):
    zipf = zipfile.ZipFile(FILE, 'r')
    zipf.extractall('data')
    zipf.close()

os.chdir('data')

cats = sorted(glob('PetImages/Cat/*'))
dogs = sorted(glob('PetImages/Dog/*'))

os.makedirs('train/cats', exist_ok=True)
os.makedirs('train/dogs', exist_ok=True)
os.makedirs('val/cats',   exist_ok=True)
os.makedirs('val/dogs',   exist_ok=True)

for i in range(1000):
    cat = cats[i]
    copy(cat, 'train/cats/' + os.path.basename(cat))
    dog = dogs[i]
    copy(dog, 'train/dogs/' + os.path.basename(dog))

for i in range(1000, 1500):
    cat = cats[i]
    copy(cat, 'val/cats/' + os.path.basename(cat))
    dog = dogs[i]
    copy(dog, 'val/dogs/' + os.path.basename(dog))

