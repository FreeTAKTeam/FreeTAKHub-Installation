FROM python:3.11

RUN groupadd -r freetak && useradd -m -r -g freetak freetak

RUN mkdir -p /home/freetak/data && chown -R freetak:freetak /home/freetak/data && chmod 777 -R /home/freetak/data && chmod g+s /home/freetak/data

# Link /opt to home data, as default configs put the db in /opt
RUN ln -s /opt/ /home/freetak/data/

USER freetak
WORKDIR /home/freetak/data

# Install pre-reqs then the base FTS
ENV PATH /home/freetak/.local/bin:/home/freetak/.local/lib:$PATH

# flask_cors is missing from the pip imports, so install it manually
RUN pip install "flask_cors"
RUN pip install FreeTAKServer-UI

# Provide a way to edit the configuration from outside the container
RUN mv $(python -m site --user-site)/FreeTAKServer-UI/config.py $(python -m site --user-site)/FreeTAKServer-UI/config.bak

WORKDIR /home/freetak
COPY --chown=freetak:freetak --chmod=774 ui-run.sh ./

VOLUME /home/freetak/data
CMD ["/home/freetak/ui-run.sh"]
