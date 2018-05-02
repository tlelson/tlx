import sys
from setuptools import setup, find_packages
import os

here = os.path.dirname(os.path.realpath(__file__))


def get_install_requires():
    with open(os.path.join(here, 'requirements.txt'), 'r') as f:
        return f.read().splitlines()


def get_version():
    with open(os.path.join(here, 'version.txt'), 'r') as f:
        return f.readline().split()[0]  # Filter out other junk


# Completely unnessesary but testing bitbucket pipelines and observing PyPi files
def get_python_version(py_version):
    return "{}.{}".format(py_version.major, py_version.minor)


setup(
    name='tlx',
    version=get_version() + '_' + get_python_version(sys.version_info),
    description='Frequently used utilities and code.',
    url='https://github.com/eL0ck/tlx',
    author='eL0ck',
    author_email='tpj800@gmail.com',
    license='Apache',
    python_requires='~=' + get_python_version(sys.version_info),
    packages=find_packages(),
    install_requires=get_install_requires(),
    zip_safe=False,
)
