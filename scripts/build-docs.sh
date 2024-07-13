#!/usr/bin/env bash

set -euo pipefail

cd docs && npm ci && npm run build
