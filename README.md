# map2stl
Generates 3D-printable object in STL format from OpenStreetMap data

* [ONLINE DEMO](http://davr.org/map2stl)

Calls the OpenStreetMap API to request roads/features/etc near the given address. A ruby script on the server generates an
OpenJSCAD script, which gets run in the browser to generate the model, which can be exported as a STL suitable for 3d printing

Uses [OpenJSCAD](https://github.com/Spiritdude/OpenJSCAD.org) and the [OpenStreetMap Overpass API](https://wiki.openstreetmap.org/wiki/Overpass_API)

The majority of my code is in osm.rb, the rest is mostly stock OpenJSCAD files (the webgl shader was modified to change the look of the 3d object)
