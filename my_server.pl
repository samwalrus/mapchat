/*  Part of SWI-Prolog

    Author:        Jan Wielemaker
    E-mail:        J.Wielemaker@cs.vu.nl
    WWW:           http://www.swi-prolog.org
    Copyright (C): 2014, VU University Amsterdam

    This program is free software; you can redistribute it and/or
    modify it under the terms of the GNU General Public License
    as published by the Free Software Foundation; either version 2
    of the License, or (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public
    License along with this library; if not, write to the Free Software
    Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA

    As a special exception, if you link this library with other files,
    compiled with a Free Software compiler, to produce an executable, this
    library does not by itself cause the resulting executable to be covered
    by the GNU General Public License. This exception does not however
    invalidate any other reasons why the executable file might be covered by
    the GNU General Public License.
*/

:- module(my_server,
	  [ server/0,
	    server/1,				% ?Port
	    create_chat_room/0
	  ]).
:- use_module(library(http/thread_httpd)).
:- use_module(library(http/http_dispatch)).
:- use_module(library(http/websocket)).
:- use_module(library(http/html_write)).
:- use_module(library(http/js_write)).
:- use_module(library(http/http_error)).
:- use_module(library(http/http_files)).
:- use_module(library(http/json)).
:- use_module(library(debug)).
:- use_module(library(time)).
:- use_module(library(http/http_unix_daemon)).

:- use_module(hub).

:- multifile http:location/3.
:- dynamic   http:location/3.
:- dynamic   ids/2.
http:location(files, '/f', []).


/** <module> A scalable websocket based chat server in SWI-Prolog

Chat servers are an example of   services  that require mixed initiative
and may be used to serve many connections. One way to implement is using
long-polling: the browser asks for events   from  the server. The server
waits until there is an event or  it   times  out  after -say- 1 minute,
after which the server replies there are  no events and the client tries
again. The long polling structure can   be implemented in the SWI-Prolog
server architecture, but it is  rather   expensive  because it implies a
Prolog thread for each blocking call.

This demo application implements  a   chatroom  using  _websockets_. The
implementation uses hub.pl, which bundles   the  responsibility for
multiple  websockets  in  a  small  number   of  threads  by  using  I/O
multiplexing based on wait_for_input/3. As a   user of hub.pl, life
is fairly straighforward:

  - Chreate a hub using hub_create/3 and a thread that
    listens to chat events and broadcasts the changes.

  - Serve a web page that provides the chat frontend.  The frontend
    contains JavaScript that establishes a websocket on /chat.  If
    a websocket is obtained, hand it to to the room using
    hub_add/2
*/


%%	server is det.
%%	server(?Port) is det.
%
%	Create the chat room and start the   server. The default port is
%	3050.

server :-
	server(3050).

server(Port) :-
	(   debugging(chat),
	    current_prolog_flag(gui, true)
	->  prolog_ide(thread_monitor)
	;   true
	),
	create_chat_room,
	http_server(http_dispatch, [port(Port)]),
	format(user_error, 'Started server at http://localhost:~d/~n', [Port]).

% setup the HTTP location. The  first   (/)  loads  the application. The
% loaded application will create  a   websocket  using  /chat. Normally,
% http_upgrade_to_websocket/3 runs call(Goal, WebSocket)  and closes the
% connection if Goal terminates. Here, we use guarded(false) to tell the
% server we will take responsibility for the websocket.

:- http_handler(root(.),    chat_page,      []).
:- http_handler(root(home),    home_page,      []).

:- http_handler(files(.), http_reply_from_files('assets', []), [prefix]).


:- http_handler(root(chat),
		http_upgrade_to_websocket(
		    accept_chat,
		    [ guarded(false),
		      subprotocols([chat])
		    ]),
		[ id(chat_websocket)
		]).

home_page(_Request):-
	reply_html_page(
	    [title('Sam Neaves home page'),
	    script([type='text/javascript',src=''],[])

	    ],
	    \home_page
	).


chat_page(_Request) :-
	reply_html_page(
	    [meta([charset='utf-8']),
	     title('Map and Chat'),
	     meta([name='viewport',content='initial-scale=1,maximum-scale=1,user-scalable=no']),
	     script([type='text/javascript',src='http://d3js.org/d3.v3.min.js'],[]),
	     script([type='text/javascript',
		    src='https://api.tiles.mapbox.com/mapbox.js/v2.1.9/mapbox.js'],[]),
             %%%%%color picker%%%%%%%%%%%
             script([type="text/javascript", src="/f/scripts/jscolor/jscolor.js"],[]),

	     %%%%%%%For leafletdraw%%%%%%
              link([href='f/scripts/Leaflet.draw-master/dist/leaflet.draw.css', rel='stylesheet'],[]),

            script([type='text/javascript',
                    src="f/scripts/Leaflet.draw-master/src/Leaflet.draw.js"],[]),
            script([type='text/javascript',
		src="f/scripts/Leaflet.draw-master/src/edit/handler/Edit.Poly.js"],[]),
		script([type='text/javascript',
			src="f/scripts/Leaflet.draw-master/src/edit/handler/Edit.SimpleShape.js"],[]),
		script([type='text/javascript',
			src="f/scripts/Leaflet.draw-master/src/edit/handler/Edit.Circle.js"],[]),
		script([type='text/javascript',
			src="f/scripts/Leaflet.draw-master/src/edit/handler/Edit.Rectangle.js"],[]),
		script([type='text/javascript',
			src="f/scripts/Leaflet.draw-master/src/draw/handler/Draw.Feature.js"],[]),
		script([type='text/javascript',
			src="f/scripts/Leaflet.draw-master/src/draw/handler/Draw.Polyline.js"],[]),
		script([type='text/javascript',
			src="f/scripts/Leaflet.draw-master/src/draw/handler/Draw.Polygon.js"],[]),
		script([type='text/javascript',
			src="f/scripts/Leaflet.draw-master/src/draw/handler/Draw.SimpleShape.js"],[]),
		script([type='text/javascript',
			src="f/scripts/Leaflet.draw-master/src/draw/handler/Draw.Rectangle.js"],[]),
		script([type='text/javascript',
			src="f/scripts/Leaflet.draw-master/src/draw/handler/Draw.Circle.js"],[]),
		script([type='text/javascript',
			src="f/scripts/Leaflet.draw-master/src/draw/handler/Draw.Marker.js"],[]),

		script([type='text/javascript',
			src="f/scripts/Leaflet.draw-master/src/ext/LatLngUtil.js"],[]),
		script([type='text/javascript',
			src="f/scripts/Leaflet.draw-master/src/ext/GeometryUtil.js"],[]),
		script([type='text/javascript',
			src="f/scripts/Leaflet.draw-master/src/ext/LineUtil.Intersect.js"],[]),
		script([type='text/javascript',
			src="f/scripts/Leaflet.draw-master/src/ext/Polyline.Intersect.js"],[]),
		script([type='text/javascript',
			src="f/scripts/Leaflet.draw-master/src/ext/Polygon.Intersect.js"],[]),

		script([type='text/javascript',
			src="f/scripts/Leaflet.draw-master/src/Control.Draw.js"],[]),
		script([type='text/javascript',
			src="f/scripts/Leaflet.draw-master/src/Tooltip.js"],[]),
		script([type='text/javascript',
			src="f/scripts/Leaflet.draw-master/src/Toolbar.js"],[]),

		script([type='text/javascript',
			src="f/scripts/Leaflet.draw-master/src/draw/DrawToolbar.js"],[]),
		script([type='text/javascript',
			src="f/scripts/Leaflet.draw-master/src/edit/EditToolbar.js"],[]),
		script([type='text/javascript',
			src="f/scripts/Leaflet.draw-master/src/edit/handler/EditToolbar.Edit.js"],[]),
		script([type='text/javascript',
			src="f/scripts/Leaflet.draw-master/src/edit/handler/EditToolbar.Delete.js"],[]),



            %%%%%%End leafletdraw%%%%%%%



             script([type='text/javascript',
		    src='/f/scripts/Leaflet.MakiMarkers.js'],[]),
	     link([href='https://api.tiles.mapbox.com/mapbox.js/v2.1.9/mapbox.css', rel='stylesheet'],[]),
             \map_style

	    ],
	    \chat_page).

home_page -->
	html([h1('Sam Neaves'),
	      p('This is my home page')
	     ]).

map_page -->
	html([h1('Map Chat!'),
	      div([id='map'],'')

	     ]),
	     map_script.

%%	chat_page//
%
%	Generate the web page.

chat_page -->
	style,
	html([
	       \map_page,
	       div([ id(chat)
		   ], []),
               input([class(color), id(color),value('f06eaa'),
			onchange("drawControl.setDrawingOptions({rectangle: {shapeOptions: {color: '#'+this.color}},
                                                                circle: {shapeOptions: {color: '#'+this.color}},
								polyline: {shapeOptions: {color: '#'+this.color}},
								polygon: {shapeOptions: {color: '#'+this.color}}
								});")],[]),
	       input([ placeholder('Type a message and hit RETURN'),
		       id(input),
		       onkeypress('handleInput(event)')
		     ], [])
	     ]),
	script.

%%	style//
%
%	Emit the style sheet. Typically, this  comes from a static file.
%	We generate it inline  here  to   keep  everything  in one file.
%	Second best would be to use a   quasi quotation, but the library
%	does not provide a  CSS  quasi   quotation  (yet).  As  CSS does
%	contains few special characters, this is bearable.

style -->
	html(style([ 'h1 {text-align: center}\n',
                     '#color {position:relative; top:20em; left: 1em; z-index: 2001; width:1.5em;}\n',
		     'body,html { height:100%; overflow: hidden; }\n',
		     '#chat { position:absolute; bottom:3em; width:100%;\c
			      height: calc(40% - 150px); overflow-y:scroll; \c
			      border: solid 1px black; padding:5px; }\n',
		     '#input {
			   position:absolute; bottom:2em; width:100%;\c
			   width:100%; border:solid 1px black; \c
			       padding: 5px; box-sizing: border-box; }\n'
		   ])).

map_style -->
	html(style(['body { margin:0; padding:0; }\n',
                    '#map { position:absolute; top:5em; bottom:0; width:100%;\c
                            %margin-left: 10em;\c
                            margin-right:auto; }\n',
		    '#map { height: 60%; }\n'
		    %'div {background-color: #b0c4de;#}\n'
		   ])).

%%	script//
%
%	Generate the JavaScript  that  establishes   the  websocket  and
%	handles events on the websocket.

script -->
	{ http_link_to_id(chat_websocket, [], WebSocketURL)
	},
	js_script({|javascript(WebSocketURL)||
function handleInput(e) {
  if ( !e ) e = window.event;  // IE
  if ( e.keyCode == 13 ) {
    var msg = document.getElementById("input").value;
    sendChatAsJson(msg);
    document.getElementById("input").value = "";
  }
}

var connection;

function openWebSocket() {
  connection = new WebSocket("ws://"+window.location.host+WebSocketURL,
			     ['chat']);

  connection.onerror = function (error) {
    console.log('WebSocket Error ' + error);
  };

  connection.onmessage = function (e) {
    var chat = document.getElementById("chat");
    var span = document.createElement("span");
    var msg = document.createElement("div");
    span.appendChild(document.createTextNode("___"));
    msg.appendChild(span);
    //msg.appendChild(document.createTextNode(e.data));

    //span.style.backgroundColor = "red";
    //alert(e);
    var stringdata = e.data;
    //alert(stringdata);

    var messageParsed = JSON.parse(stringdata);

    if(messageParsed.hasOwnProperty("type")){
      if(messageParsed.type=="msg"){
          var r = messageParsed.rgb[0];
          var g = messageParsed.rgb[1];
          var b = messageParsed.rgb[2];

          var hex = rgbToHex(r, g, b);
          span.style.backgroundColor = hex;
          msg.appendChild(document.createTextNode(messageParsed.msg));
          var child = chat.appendChild(msg);
          child.scrollIntoView(true);
      }
      if(messageParsed.type=="marker_loc"){
         //alert("got marker");
         my_add_marker(stringdata);
      }

      if(messageParsed.type=="remove_marker"){
         //console.log("removing marker");
         my_remove_marker(stringdata);
      }

      if(messageParsed.type=="marker"){
         //alert("got marker");
         my_add_pin(stringdata);
      }

      if(messageParsed.type=="circle"){
         //alert("got circle");
         my_add_circle(stringdata);
      }

      if(messageParsed.type=="rectangle"){
         //alert("got rectangle");
         my_add_rectangle(stringdata);
      }

      if(messageParsed.type=="polyline"){
         //alert("got polyline");
         my_add_polyline(stringdata);
      }

      if(messageParsed.type=="polygon"){
         //alert("got polygon");
         my_add_polygon(stringdata);
      }


    }

  };
}

var my_obj = {};

function my_add_marker(data){

    my_var = JSON.parse(data);

    if (my_obj.hasOwnProperty(my_var.id)) {

       map.removeLayer(my_obj[my_var.id]);
       }

    var hex = rgbToHex(my_var.rgb[0],my_var.rgb[1],my_var.rgb[2])
    var icon = L.MakiMarkers.icon({icon: "zoo", color: hex, size: "m"});
    my_obj[my_var.id] = new L.marker([my_var.LatLng[0],my_var.LatLng[1]],{icon: icon}).addTo(map);

}

function my_remove_marker(data){

    my_var = JSON.parse(data);

    if (my_obj.hasOwnProperty(my_var.id)) {

       map.removeLayer(my_obj[my_var.id]);
       }

}

var added_pins = {};
function my_add_pin(data){

    my_var = JSON.parse(data);
    var hex = rgbToHex(my_var.rgb[0],my_var.rgb[1],my_var.rgb[2])
    //var icon = L.MakiMarkers.icon({icon: "zoo", color: hex, size: "m"});
    added_pins[my_var.id] = new L.marker([my_var.LatLng[0],my_var.LatLng[1]]).addTo(map);

}

var added_circles = {};
function my_add_circle(data){

    my_var = JSON.parse(data);
    //var hex = rgbToHex(my_var.rgb[0],my_var.rgb[1],my_var.rgb[2])
    var color = '#'+my_var.color;
    //console.log("color is:");
    //console.log(color);
    var rad = my_var.radius;
    //var icon = L.MakiMarkers.icon({icon: "zoo", color: hex, size: "m"});
    added_circles[my_var.id] = new L.circle([my_var.LatLng[0],my_var.LatLng[1]],rad,{"color":color, "fillOpacity":0.2}).addTo(map);

}

var added_rectangles = {};
function my_add_rectangle(data){

    my_var = JSON.parse(data);
    //console.log(data);
    var color = '#'+my_var.color;
    var bounds = [[my_var.southWest[0],my_var.southWest[1]],[my_var.northEast[0],my_var.northEast[1]]];
    added_rectangles[my_var.id] = new L.rectangle(bounds,{"color":color, "fillOpacity":0.2}).addTo(map);

}

var added_polygons ={};
function my_add_polygon(data){

    my_var = JSON.parse(data);
    //console.log(data);
    var color = '#'+my_var.color;
    var latlngs = my_var.latlngs;
    added_polygons[my_var.id] = new L.polygon(latlngs,{"color":color, "fillOpacity":0.2}).addTo(map);

}

var added_polylines ={};
function my_add_polyline(data){

    my_var = JSON.parse(data);
    //console.log(data);
    var color = '#'+my_var.color;
    var latlngs = my_var.latlngs;
    added_polylines[my_var.id] = new L.polyline(latlngs,{"color":color, "fillOpacity":0.2}).addTo(map);

}




function get_my_simple_id(){
   // function that querys the websocket server to find out what simple id this client has

}

function sendChatAsJson(msg) {
  var msgObject =
  { "type":"msg",
    "msg":msg
  };
  var stringMessage = JSON.stringify(msgObject);
  connection.send(stringMessage);
}

function sendChat(msg) {
  connection.send(msg);
}

window.addEventListener("DOMContentLoaded", openWebSocket, false);
		  |}).

map_script -->
	js_script({|javascript||
    L.mapbox.accessToken = 'pk.eyJ1Ijoic2Ftd2FscnVzIiwiYSI6IlRWUWVzeTQifQ.Z-JEsIxDfbr7kZI3MjUFBQ';



    //alert(Location);
    var map = L.mapbox.map('map', 'mapbox.streets')
        //.setView([51.5, -0.09], 13);
        /*This is for testing adding a basic marker and circle from the cleint
	var marker = L.marker([51.5, -0.09]).addTo(map);
	var circle = L.circle([51.508, -0.11], 500, {
        color: 'red',
        fillColor: '#f03',
        fillOpacity: 0.5
        }).addTo(map);
        */

    /******************/
    // Initialise the FeatureGroup to store editable layers
	var drawnItems = new L.FeatureGroup();
	map.addLayer(drawnItems);
	// Initialise the draw control and pass it the FeatureGroup of editable layers
	var drawControl = new L.Control.Draw({
                edit: {
			featureGroup: drawnItems
		}
	});
	map.addControl(drawControl);



	map.on('draw:created', function (e) {
		var type = e.layerType,
		layer = e.layer;
                var objectToSend ={};
                var latlng;
		if (type === 'marker') {
			//alert(layer.getLatLng());
                        latlng = layer.getLatLng();
                        objectToSend.type = 'marker';
                        objectToSend.lat = latlng.lat;
                        objectToSend.lng = latlng.lng;
                        var jsonObjectToSend = JSON.stringify(objectToSend);
                        //alert(jsonObjectToSend);
                        sendChat(jsonObjectToSend);
                        //objectToSend.color = layer.getColor(); //will this work?
		}

                if (type === 'circle'){
                      //alert('circle');
                      objectToSend.type = 'circle';
                      objectToSend.latlng = layer.getLatLng();
		      //objectToSend.lat = layer.getLat();

                      objectToSend.radius = layer.getRadius();
                      objectToSend.color =  document.getElementById("color").value;;
                      //objectToSend.fillcolor =  layer.fillcolor(); //work?
                      var jsonObjectToSend = JSON.stringify(objectToSend);
		      //alert(jsonObjectToSend);
		      sendChat(jsonObjectToSend);
		      //map.addLayer(layer);
                }


                if (type === 'rectangle'){
                      objectToSend.type = 'rectangle';
		      bounds =layer.getBounds();
		      //console.log(temp["_southWest"]);
                      objectToSend.southWest = bounds["_southWest"];
		      objectToSend.northEast = bounds["_northEast"];
                      objectToSend.color =  document.getElementById("color").value;;
                      //objectToSend.fillcolor =  layer.fillcolor();
                      var jsonObjectToSend = JSON.stringify(objectToSend);
                      //alert(jsonObjectToSend);
		      sendChat(jsonObjectToSend);

		     // map.addLayer(layer);
                }

                if (type === 'polygon'){
                      objectToSend.type = 'polygon';
                      objectToSend.latlngs = layer.getLatLngs();
                      objectToSend.color =  document.getElementById("color").value;;
                      //objectToSend.fillcolor =  layer.fillcolor();
                      var jsonObjectToSend = JSON.stringify(objectToSend);
                      //alert(jsonObjectToSend);
		      sendChat(jsonObjectToSend);

		      //map.addLayer(layer);
                }

                if (type === 'polyline'){
                      objectToSend.type = 'polyline';
                      objectToSend.latlngs = layer.getLatLngs();
                      objectToSend.color =  document.getElementById("color").value;;
                      //objectToSend.fillcolor =  layer.fillcolor();
                      var jsonObjectToSend = JSON.stringify(objectToSend);
                      //alert(jsonObjectToSend);
		      sendChat(jsonObjectToSend);

                      //map.addLayer(layer);
                }

		// Do whatever else you need to. (save to db, add to map etc)
		//map.addLayer(layer);
	});
    /*****************/

    function success(pos) {
       var crd = pos.coords;

      alert('Your current position is:');
      alert('Latitude : ' + crd.latitude);
      alert('Longitude: ' + crd.longitude);
      alert('More or less ' + crd.accuracy + ' meters.');
      return crd;
    };
    //Location = navigator.geolocation.getCurrentPosition(success);
    //alert(Location.latitude);
    //alert(Location.longitude);
    //marker.bindPopup("<b>Hello world!</b><br>I am a popup.").openPopup();
    //circle.bindPopup("I am a circle.");
    //alert(rgbToHex(10,10,10));
    function rgbToHex(r, g, b) {
       return "#" + ((1 << 24) + (r << 16) + (g << 8) + b).toString(16).slice(1);
    }


    getLocation();
    markerLocation();
    var my_new;

    /*Function for adding an onclick alert for co-ords
    map.on('click', function(e){
	  alert(e.latlng);
	  if (my_new) {
	     //alert('I am there');
	     map.removeLayer(my_new);
	  }
	  my_new = new L.marker(e.latlng).addTo(map);


	});

     */
        var lat;
        var lng;
	function getLocation() {
	    //alert("got to function");
          var myPos;
          if (navigator.geolocation) {
           //alert("here");
           navigator.geolocation.getCurrentPosition(mapAtPosition);
           //alert([myPos.coords.latitude, myPos.coords.longitude]);
          } else {
           alert("Geolocation is not supported by this browser.");
          }
        }

        function markerLocation() {
	    //alert("got to function");
          if (navigator.geolocation) {
           navigator.geolocation.getCurrentPosition(setMarkerLocation);
          } else {
           alert("Geolocation is not supported by this browser.");
          }
        }

    function setMarkerLocation(position) {
	    //alert("got to show position");
            //var marker_me = L.marker([position.coords.latitude, position.coords.longitude]).addTo(map);
            //marker_me.bindPopup("<b>You are here</b><br>I am a popup.").openPopup();
            lat = position.coords.latitude;
            lng = position.coords.longitude;

    }

    //map.setView([51.47604, -2.71], 13);
    function mapAtPosition(position) {
	    //alert("got to show position");
        //var marker_me = L.marker([position.coords.latitude, position.coords.longitude]).addTo(map);
		//marker_me.bindPopup("<b>You are here</b><br>I am a popup.").openPopup();
         map.setView([position.coords.latitude, position.coords.longitude], 13);
         //alert("here");

    }

    setInterval(function ()
        {
           var stringJson;
           var currentdate = new Date();
           var datetime = "Last Sync: " + currentdate.getDate() + "/"
                + (currentdate.getMonth()+1)  + "/"
                + currentdate.getFullYear() + " @ "
                + currentdate.getHours() + ":"
                + currentdate.getMinutes() + ":"
                + currentdate.getSeconds();
           //alert(datetime)
           markerLocation();
           //sendChat(datetime);
           stringJson = JSON.stringify({type: "marker_loc", lat: lat, lng: lng});
           sendChat(stringJson);
        }
        , 5000);





		  |}).

%%	accept_chat(+WebSocket) is det.
%
%	Normally,  the  goal  called    by   http_upgrade_to_websocket/3
%	processes all communication with the   websocket in a read/write
%	loop. In this case however,  we tell http_upgrade_to_websocket/3
%	that we will take responsibility for   the websocket and we hand
%	it to the chat room.

accept_chat(WebSocket) :-
	hub_add(chat, WebSocket, _Id).

%%	create_chat_room
%
%	Create our actual chat room.

:- dynamic
	utterance/1,			% messages
	visitor/3,			% joined visitors
	my_room/1,
        simple_user/1.

simple_user(0).

create_chat_room :-
	hub_create(chat, Room, _{}),
	thread_create(chatroom(Room), _, [alias(chatroom)]).

%%	chatroom(+Room)
%
%	Realise the chatroom main loop: listen  for an event, update the
%	state and possibly broadcast status updates.

chatroom(Room) :-
	thread_get_message(Room.queues.event, Message),
	handle_message(Message, Room),
	chatroom(Room).

handle_message(Message, Room) :-
	websocket{opcode:text} :< Message, !,
	%assertz(my_room(Room)),
	Message = websocket{client:Client,data:M,format:_F,hub:_C,opcode:_T},
	my_if(M,Room,Message,Client).

handle_message(Message, _Room) :-
	hub{joined:Id} :< Message, !,
	get_remove(Simple_Id),%when someone is new to the thing add simple id
	random_between(0,255,R),
	random_between(0,255,G),
	random_between(0,255,B),
	assertz(visitor(Id,Simple_Id,rgb(R,G,B))),
	forall(utterance(Utterance),
	       (
	       Utterance = websocket{client:Client,data:M,format:F,hub:C,opcode:T},
	       string_codes(M,Codes),
               atom_codes(Atom,Codes),
	       atom_json_dict(Atom,Json,[as(string)]),
	       visitor(Client,Simple_Client,rgb(R2,G2,B2)),
	       _A{type:Message_type, msg:Msg} :< Json,
	       %format("Message type: ~w  msg: ~w client: ~w  rgb:~w~w~w~n~n",[Message_type, Msg,Simple_Client,R2,G2,B2]),
               format(atom(JsonSend),'{"type":"~w", "msg":"~w", "id":~w, "rgb":[~w,~w,~w]}',
	           ['msg', Msg,Simple_Client,R2,G2,B2]),
	       %format("~w",[JsonSend]),
	       U2 = websocket{client:Client,data:JsonSend,format:F,hub:C,opcode:T},
	       %format("~w~n~n~w~n",[Utterance,U2]),
	       hub_send(Id, U2)
	       )
	      ).
handle_message(Message, _Room) :-
	hub{left:Id} :< Message, !,
	retractall(visitor(Id,_Simple_Id,_RGB)).
handle_message(Message, _Room) :-
	debug(chat, 'Ignoring message ~p', [Message]).

my_utterance(M):-
	utterance(websocket{client:_Client,data:M,format:_F,hub:_C,opcode:_T}).

send_message(Message):-
	M = websocket{
		client:'2b3da57c-edab-11e4-a190-67c7e32ddf80',
		data:Message, format:string, hub:chat,opcode:text},
	current_hub(chat,Hub),
	hub_broadcast(Hub.name,M).

broad_cast_remove_pin(_Room,Id):-
	format(atom(MsgJson),'{"type":"remove_marker","id":"~w"}',[Id]),
	send_message(MsgJson).


broad_cast_loc_pin(_Room,Id,Lat,Lng,R,G,B,MsgJson):-
	format(atom(MsgJson),'{"type":"marker_loc","id":"~w", "LatLng":[~w,~w], "rgb":[~w,~w,~w]}',[Id,Lat,Lng,R,G,B]),
	send_message(MsgJson).
	%hub_broadcast(Room.name, Message).

broad_cast_pin(_Room,Id,Lat,Lng,R,G,B,MsgJson):-
	format(atom(MsgJson),'{"type":"marker","id":"~w", "LatLng":[~w,~w], "rgb":[~w,~w,~w]}',[Id,Lat,Lng,R,G,B]),
	send_message(MsgJson).
	%hub_broadcast(Room.name, Message).

broad_cast_circle(_Room,Id,Lat,Lng,Color,Radius,MsgJson):-
	format(atom(MsgJson),'{"type":"circle","id":"~w", "LatLng":[~w,~w], "radius":~w, "color":"~w"}',[Id,Lat,Lng,Radius,Color]),
	send_message(MsgJson).
	%hub_broadcast(Room.name, Message).

broad_cast_rectangle(_Room,Id,Bounds,Color,MsgJson):-
	Bounds = bounds(SwLat,SwLng, NeLat,NeLng),
	format(atom(MsgJson),'{"type":"rectangle","id":"~w", "southWest":[~w,~w],"northEast":[~w,~w],"color":"~w"}',[Id,SwLat,SwLng,NeLat,NeLng,Color]),
	send_message(MsgJson).
	%hub_broadcast(Room.name, Message).

broad_cast_polygon(_Room,Id,LatLngs,Color,MsgJson):-
	atom_json_dict(LatLngsArray,LatLngs,[as(atom)]),
	format(atom(MsgJson),'{"type":"polygon","id":"~w", "latlngs":~w,"color":"~w"}',[Id,LatLngsArray,Color]),
	send_message(MsgJson).
	%hub_broadcast(Room.name, Message).

broad_cast_polyline(_Room,Id,LatLngs,Color,MsgJson):-
	atom_json_dict(LatLngsArray,LatLngs,[as(atom)]),
	format(atom(MsgJson),'{"type":"polyline","id":"~w", "latlngs":~w,"color":"~w"}',[Id,LatLngsArray,Color]),
	send_message(MsgJson).
	%hub_broadcast(Room.name, Message).





broad_cast_msg_as_json(_Room,Id,Msg,R,G,B,MsgJson):-
	format(atom(MsgJson),'{"type":"msg","id":"~w","msg":"~w","rgb":[~w,~w,~w]}',[Id,Msg,R,G,B]),
	%format('~w\n',[Msg]),
	send_message(MsgJson).
	%hub_broadcast(Room.name, Message).




% {"type":"marker_loc", "lat":51.5,"lng":-2.65}
my_if(M,_Room,_Message,Client):-
        %trace,
        string_codes(M,Codes),
        atom_codes(Atom,Codes),
	atom_json_dict(Atom,Json,[as(string)]),
	%trace,
	%format("~w\n~w\n",[Json,Client]),
	visitor(Client,Simple_Client,rgb(R,G,B)),
	_A{type:"marker_loc", lat:Lat, lng:Lng} :< Json,!,
	broad_cast_loc_pin(_Room2,Simple_Client,Lat,Lng,R,G,B,_Msg),
	my_remove_alarm(Simple_Client),
	set_alarm(Simple_Client).

my_if(M,_Room,_Message,Client):-
        %trace,
        string_codes(M,Codes),
        atom_codes(Atom,Codes),
	atom_json_dict(Atom,Json,[as(string)]),
	%trace,
	%format("~w\n~w\n",[Json,Client]),
	visitor(Client,Simple_Client,rgb(R,G,B)),
	_A{type:"marker",lat:Lat, lng:Lng} :< Json,!,
        %format("~w~n",[Json]).
	broad_cast_pin(_Room2,"test_one",Lat,Lng,10,10,10,_MsgJson). %id of broadcast pin is fixed at the moment


my_if(M,_Room,_Message,Client):-
        %trace,
        string_codes(M,Codes),
        atom_codes(Atom,Codes),
	atom_json_dict(Atom,Json,[as(string)]),
	%trace,
	%format("~w\n~w\n",[Json,Client]),
	visitor(Client,Simple_Client,rgb(R,G,B)),
	_A{type:"circle",latlng:LatLngJson,radius:Radius,color:Color} :< Json,!,
	_{lat:Lat,lng:Lng} :< LatLngJson,!,
        %format("~w~n",[Json]).
	broad_cast_circle(_Room2,"test_c_one",Lat,Lng,Color,Radius,_MsgJson). %id of broadcast circle is fixed at the moment


my_if(M,_Room,_Message,Client):-
        %trace,
        string_codes(M,Codes),
        atom_codes(Atom,Codes),
	atom_json_dict(Atom,Json,[as(string)]),
	%trace,
	%format("~w\n~w\n",[Json,Client]),
	visitor(Client,Simple_Client,rgb(R,G,B)),
	_A{type:"rectangle", southWest:SouthWestLatLng,northEast:NorthEastLatLng,color:Color} :< Json,!,
	_A{lat:SwLat,lng:SwLng} :< SouthWestLatLng,!,
	_A{lat:NeLat,lng:NeLng} :< NorthEastLatLng,!,
        %format("~w~n",[Json]).
	Bounds = bounds(SwLat,SwLng, NeLat,NeLng),
	broad_cast_rectangle(_Room2,"test_r_one",Bounds,Color,_MsgJson). %id of broadcast rectangle is fixed at the moment


my_if(M,_Room,_Message,Client):-
        %trace,
        string_codes(M,Codes),
        atom_codes(Atom,Codes),
	atom_json_dict(Atom,Json,[as(string)]),
	%trace,
	%format("~w\n~w\n",[Json,Client]),
	visitor(Client,Simple_Client,rgb(R,G,B)),
	_A{type:"polygon", latlngs:LatLngs,color:Color} :< Json,!,
        %format("~w~n",[Json]).
	broad_cast_polygon(_Room2,"test_pg_one",LatLngs,Color,_MsgJson). %id of broadcast polygon is fixed at the moment

my_if(M,_Room,_Message,Client):-
        %trace,
        string_codes(M,Codes),
        atom_codes(Atom,Codes),
	atom_json_dict(Atom,Json,[as(string)]),
	%trace,
	%format("~w\n~w\n",[Json,Client]),
	visitor(Client,Simple_Client,rgb(R,G,B)),
	_A{type:"polyline", latlngs:LatLngs,color:Color} :< Json,!,
        %format("~w~n",[Json]).
	broad_cast_polyline(_Room2,"test_pl_one",LatLngs,Color,_MsgJson). %id of broadcast polyline is fixed at the moment






my_if(M,Room,Message,Client):-
	assertz(utterance(Message)),
	string_codes(M,Codes),
        atom_codes(Atom,Codes),
	atom_json_dict(Atom,Json,[as(string)]),
	visitor(Client,Simple_Client,rgb(R,G,B)),
	_A{type:Message_type, msg:Msg} :< Json,!,
	format(atom(JsonSend),'{"type":"~w", "msg":"~w", "id":~w, "rgb":[~w,~w,~w]}',
	       [Message_type, Msg,Simple_Client,R,G,B]),
	%format('~w',[JsonSend]),
        send_message(JsonSend).

	%hub_broadcast(Room.name, Message).


		%send_message('message_was:'),send_message(M).

get_remove(X):-
	simple_user(X),
        retract(simple_user(X)),
	Y is X+1,
	assertz(simple_user(Y)).


set_alarm(Node_Id):-
	%trace,
	alarm(10, fire_alarm(Node_Id), Alarm_Id, [remove(true)]),
	assertz(ids(Node_Id,Alarm_Id)).
	%format("msg from ~w alarm set~n",[Node_Id, Alarm_Id]).


my_remove_alarm(Node_Id):-
	ids(Node_Id,Alarm_Id),
	remove_alarm(Alarm_Id),
	retract(ids(Node_Id,_)).

%If the alarm does not exist do nothing.
my_remove_alarm(_).

fire_alarm(Node_Id):-
	%format("~w has not reported its location for 10 seconds!",[Node_Id]),
	broad_cast_remove_pin(_Room,Node_Id).
