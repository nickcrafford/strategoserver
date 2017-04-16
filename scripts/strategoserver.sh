#!/bin/bash

# Meant to be executed within the Docker container
cd /opt/
exec erl -pa . /opt/dist/*/ebin -boot start_sasl -s reloader -s strategoserver start 9091
