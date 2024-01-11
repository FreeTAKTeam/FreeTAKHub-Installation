#!/bin/bash

PYTHON_USER_SITE=$(python -m site --user-site)
# Detect and navigate to the python user site packages
# Some systems use `python3` instead of `python` so this is not entirely portable
cd "${PYTHON_USER_SITE}/FreeTAKServer/" || raise error "Could not navigate to the user-sites path. Are you using a distro that requires python3 instead of python?"

# Sharing for MainConfig.py
if [[ ! -f "/opt/fts/MainConfig.py" ]]
  then
    cp ${PYTHON_USER_SITE}/FreeTAKServer/core/configuration/MainConfig.bak /opt/fts/MainConfig.py
fi
if [[ ! -f "${PYTHON_USER_SITE}/FreeTAKServer/core/configuration/MainConfig.py" ]]
  then
      if [[ ! -f "/opt/fts/MainConfig.py" ]]
        then
            echo "MainConfig.py is missing from the expected volume!"
        else
            ln -s /opt/fts/MainConfig.py "${PYTHON_USER_SITE}/FreeTAKServer/core/configuration/MainConfig.py"
        fi
fi

# Sharing for FTSConfig.yaml
if [[ ! -f "/opt/fts/FTSConfig.yaml" ]]
  then
    python -c "from FreeTAKServer.core.configuration.configuration_wizard import autogenerate_config; autogenerate_config()"
fi

python -m FreeTAKServer.controllers.services.FTS
