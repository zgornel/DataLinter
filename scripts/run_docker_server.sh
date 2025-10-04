#!/bin/sh
docker run -it -p10000:10000 --volume=./config:/datalinter/config ghcr.io/zgornel/datalinter-compiled:latest /datalinterserver/bin/datalinterserver -i 0.0.0.0 --config-path /datalinter/config/default.toml --log-level debug
