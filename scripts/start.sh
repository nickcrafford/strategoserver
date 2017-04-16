#!/bin/bash

exec erl -pa . dist/*/ebin -boot start_sasl -s reloader -s strategoserver start $1
