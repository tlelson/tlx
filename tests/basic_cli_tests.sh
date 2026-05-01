#!/bin/bash
set -ev

# All command line apps should at least print their help message on all
# platforms
get-aws-creds --help
dynamo-batch-write --help
dynamo-clear-table --help
lambda --help
lambda describe --help
lambda delete --help
