FROM ubuntu

RUN apt-get update && apt-get install -y erlang git

USER root
RUN chmod 777 /opt/ 
ADD . /opt/
RUN chmod -R 777 /opt/ 
RUN cd /opt/ && ./scripts/build.sh
RUN ln -s /opt/scripts/strategoserver.sh /bin/strategoserver
CMD /bin/strategoserver
EXPOSE 9091