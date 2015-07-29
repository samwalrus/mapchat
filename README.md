This is a version of a chat server from swi prolog. It has been extended
to have a map with pins that show where each person who is chatting is.


The chat users can collaboratively and in real time add shapes as annotations
to the map. Users can choose a color and then draw a shape which is shared
in real time with other users.

The next step of the project is to intregate some rules on shapes.


 load `my_server.pl` and run

    ?- server.

This will start the  server  at  port   3050.

Then you can see the page at localhost:3050, the website has been tested in chrome.
You need to allow the site to share locations, the locations update every 5 seconds
so you dont want to be clicking allow every 5 seconds!




