FROM python:3.11

RUN groupadd -r freetak && useradd -m -r -g freetak freetak

RUN mkdir -p /home/freetak/data && chown -R freetak:freetak /home/freetak/data && chmod 777 -R /home/freetak/data && chmod g+s /home/freetak/data
RUN ln -s /opt/FTSServer-UI.db /home/freetak/data/FTSServer-UI.db

USER freetak
WORKDIR /home/freetak/data

# Install pre-reqs then the base FTS
ENV PATH /home/freetak/.local/bin:/home/freetak/.local/lib:$PATH

RUN pip install "flask<2.3" "WTForms==2.3.3" "sqlalchemy<1.4"
RUN pip install --pre --upgrade-strategy only-if-needed FreeTAKServer-UI>0.1a0

# Provide a way to edit the configuration from outside the container
RUN mv $(python -m site --user-site)/FreeTAKServer-UI/config.py $(python -m site --user-site)/FreeTAKServer-UI/config.bak

WORKDIR /home/freetak
COPY --chown=freetak:freetak --chmod=774 docker-run.sh ./

EXPOSE 5000/tcp
VOLUME /home/freetak/data
CMD ["/home/freetak/docker-run.sh"]
