This is a version of a chat server from swi prolog. It has been extended
to have a map with pins that show where each person who is chatting is.
Collab map annotation is being added.

# SWI-Prolog based chat server

This repository provides a demonstration for   using  the recently added
websocket support for realising a  chat  server.   To  use  it, you must
install *[SWI-Prolog](http://www.swi-prolog.org) 7.1.19 or later*. Then,
you can load `debug.pl` and run

    ?- server.

This will start the  server  at  port   3050  in  debug  mode, showing a
graphical window with the running server   threads and debug messages in
the console. Load `chat.pl` if you want   to run the demo interactively,
but without noisy debugging messages.

## Running as a service

The script `daemon.pl` is provided to start  the server as a Unix daemon
process. Run `./daemon.pl --help` for a  brief help message.

### Starting as an upstart job

The service can be  started  as  an   (Ubuntu)  upstart  job  by copying
`upstart/chat.conf`  to  `/etc/init`  editing  `/etc/init/chat.conf`  to
reflect the installation directory. After  that,   run  this  command to
start the server:

    % sudo service chat start

## Status

The chatserver itself is really simple.   Tested with the server running
on Linux using firefox and chromium as clients. Anne Ogborn confirmed it
also works using Windows 7 as server and IE 11.0 as client.

## Future

The library hub.pl is probably going to end up as a core library and the
demo program will than be added as a demo application.
