var links = [
    {"source":5,"value":1,"target":11},
    {"source":5,"value":1,"target":12},
    {"source":10,"value":1,"target":12},
    {"source":11,"value":1,"target":5},
    {"source":11,"value":1,"target":12},
    {"source":11,"value":1,"target":14},
    {"source":12,"value":1,"target":5},
    {"source":12,"value":1,"target":10},
    {"source":12,"value":1,"target":11},
    {"source":14,"value":1,"target":11},
    {"source":16,"value":1,"target":19},
    {"source":18,"value":1,"target":19},
    {"source":19,"value":1,"target":16},
    {"source":19,"value":1,"target":18}
];

var nodes = [
    {"name":"Vertex 5","group":"Ones"},
    {"name":"Vertex 9","group":"Zeros"},
    {"name":"Vertex 15","group":"Ones"},
    {"name":"Vertex 20","group":"Zeros"},
    {"name":"Vertex 26","group":"Ones"},
    {"name":"Vertex 29","group":"Zeros"},
    {"name":"Vertex 33","group":"Ones"},
    {"name":"Vertex 37","group":"Zeros"},
    {"name":"Vertex 49","group":"Ones"},
    {"name":"Vertex 52","group":"Zeros"},
    {"name":"Vertex 53","group":"Ones"},
    {"name":"Vertex 58","group":"Zeros"},
    {"name":"Vertex 59","group":"Ones"},
    {"name":"Vertex 65","group":"Zeros"},
    {"name":"Vertex 73","group":"Ones"},
    {"name":"Vertex 74","group":"Zeros"},
    {"name":"Vertex 80","group":"Ones"},
    {"name":"Vertex 84","group":"Zeros"},
    {"name":"Vertex 87","group":"Ones"},
    {"name":"Vertex 99","group":"Zeros"}
];

var width = 450,
    height = 500;

var color = d3.scale.category10();

var force = d3.layout.force()
    .charge(-120)
    .linkDistance(30)
    .size([width, height]);

var svg = d3.select("body").append("svg")
    .attr("width", width)
    .attr("height", height);

var force = d3.layout.force()
    .nodes(nodes)
    .links(links)
    .size([width, height])
    .start();
    
var link = svg.selectAll(".link")
    .data(links)
    .enter().append("line")
    .attr("class", "link")
    .style("stroke-width", function(d) { return Math.sqrt(d.value); });
    
// You define here your nodes and the color will be d.group
var node = svg.selectAll(".node")
    .data(nodes)
    .enter().append("circle")
    .attr("class", "node")
    .attr("r", 5)
    .style("fill", function(d) { return color(d.group); })
    .call(force.drag);
    
//Display node name when mouse on a node
node.append("title")
    .text(function(d) { return d.name; });
    
//Where and how nodes are displayed
force.on("tick", function() {
    node.attr("cx", function(d) { return d.x; })
        .attr("cy", function(d) { return d.y; });
    
    link.attr("x1", function(d) { return d.source.x; })
        .attr("y1", function(d) { return d.source.y; })
        .attr("x2", function(d) { return d.target.x; })
        .attr("y2", function(d) { return d.target.y; });
});
    
//Legend
var legend = svg.selectAll(".legend")
    .data(color.domain())
    .enter().append("g")
    .attr("class", "legend")
    .attr("transform", function(d, i) { return "translate(0," + i * 20 + ")"; });

legend.append("rect")
    .attr("x", width - 18)
    .attr("width", 18)
    .attr("height", 18)
    .style("fill", color);

legend.append("text")
    .attr("x", width - 24)
    .attr("y", 9)
    .attr("dy", ".35em")
    .style("text-anchor", "end")
    .text(function(d) { return d; });
