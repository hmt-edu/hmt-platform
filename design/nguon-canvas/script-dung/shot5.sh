#!/bin/bash
NODE_PATH=scripts/node_modules node shot5.js "$@" 2>&1 | sed 's/"c:Failed to load resource: net::ERR_FAILED",\?//g; s/,\]/]/g'
