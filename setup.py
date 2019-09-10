#!/usr/bin/env python
# -*- coding: utf-8 -*-

"""The setup script."""

from setuptools import setup, find_packages, Extension

with open('README.rst') as readme_file:
    readme = readme_file.read()

with open('HISTORY.rst') as history_file:
    history = history_file.read()

requirements = [ ]

setup_requirements = ['cython']

test_requirements = [ ]

ext_modules = [
    Extension(
        'simlightengine.base',
        ['simlightengine/base.pyx'],
        language='c++',
        extra_compile_args=["-std=c++11"],
        extra_link_args=["-std=c++11"]
    ),
]

setup(
    author="Gavin Chan",
    author_email='gavincyi@gmail.com',
    classifiers=[
        'Development Status :: 2 - Pre-Alpha',
        'Intended Audience :: Developers',
        'License :: OSI Approved :: MIT License',
        'Natural Language :: English',
        'Programming Language :: Python :: 3',
        'Programming Language :: Python :: 3.4',
        'Programming Language :: Python :: 3.5',
        'Programming Language :: Python :: 3.6',
        'Programming Language :: Python :: 3.7',
    ],
    description="A very light matching engine.",
    install_requires=requirements,
    license="MIT license",
    long_description=readme + '\n\n' + history,
    # include_package_data=True,
    keywords='simlightengine',
    name='simlightengine',
    packages=find_packages(exclude=('tests',)),
    setup_requires=setup_requirements,
    test_suite='tests',
    tests_require=test_requirements,
    url='https://github.com/simlight/simlightengine',
    version='0.1.0',
    zip_safe=False,
    ext_modules=ext_modules,
)
