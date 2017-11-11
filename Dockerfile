FROM swipl:7.6.0

# Run the image as a non-root user
RUN useradd -m -s /bin/sh myuser
USER myuser
WORKDIR /home/myuser

ADD my_server.pl $HOME
ADD hub.pl $HOME

# This does not load all the files in the folder I think
ADD assets /home/myuser/assets/
ADD upstart $HOME/upstart/

ADD d3.v3.js $HOME
ADD daemon.pl $HOME
ADD debug.pl $HOME
ADD index.html $HOME
ADD Leaflet.MakiMarkers.js $HOME
ADD map_editor.html $HOME
ADD my_d3.js $HOME
ADD stress_client.pl $HOME


ENV PORT 4000
EXPOSE 4000

#CMD ["swipl", "-f", "basic_site.pl", "-g", "server(5000)."] 
#CMD ["swipl", "basic_site.pl", "--user=daemon", "--no-fork", "--port=$PORT"]
CMD swipl daemon.pl --no-fork --port=$PORT 
