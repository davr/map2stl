#!/usr/bin/ruby

require 'net/http'
require 'json'
require 'pp'
require 'cgi'
require 'digest'

puts "Content-type: text/plain\r\n\r\n"

$stderr.reopen($stdout)

def getKeys(arr)
    keys = {}
    if(arr.is_a?(Hash)) then
        arr.each do |t, item|
            keys[t] = 0 if not keys.key?(t)
            keys[t] += 1
        end
    elsif(arr.is_a?(Array)) then
        arr.each do |item|
            t = item['type']
            keys[t] = 0 if not keys.key?(t)
            keys[t] += 1
        end
    end

    return keys
end

class OSM
    def initialize(coords=nil)
        self.coords = coords if coords
        @url = URI('http://overpass.osm.rambler.ru/cgi/interpreter')
    end

    def coords=(coords)
        coords[0], coords[2] = [coords[0], coords[2]].minmax
        coords[1], coords[3] = [coords[1], coords[3]].minmax
        @coords = coords
    end

    def params()
        return { 'data' => "[out:json];(node(#{@coords.join(', ')});<;);out;" }
    end

    def uri(url,params)
        uri = URI(url)
        uri.query = URI.encode_www_form(params)
        return uri
    end

    def loadData(lineW, lineH)
        lineW = 1.0 if not lineW
        lineH = 3.0 if not lineH
        md5 = Digest::MD5.hexdigest(@coords.to_s)
        cache = "cache/#{md5}.js"
        if File.exist?(cache) then
            @data = JSON.parse(File.open(cache,"r").read)
        else
            res = Net::HTTP.get_response(self.uri(@url, self.params))
            if(res.code.to_i != 200) then
                raise "Error code: #{res.code}! #{res.message}"
            end
            @data = JSON.parse(res.body)
            File.open(cache,"w").write(res.body)
        end
#        pp getKeys(@data)
#        pp getKeys(@data['elements'])

        @nodes = {}
        @bbox = nil
        @hwy = {}
        @ways = {}
        @data['elements'].each do |item|
            case item['type']
            when 'node'
                if(!@bbox) then @bbox = [item['lat'],item['lon'],item['lat'],item['lon']] end
                @bbox[0], @bbox[2] = [@bbox[0], @bbox[2], item['lat']].minmax
                @bbox[1], @bbox[3] = [@bbox[1], @bbox[3], item['lon']].minmax
                @nodes[item['id']] = item
            when 'way'
                @ways[item['id']] = item
                hwy = nil
                if item.key?('tags') then
                    types = %w(highway building waterway leisure amenity landuse)
                    types.each do |type|
                        if item['tags'].key?(type) then
                            hwy = item['tags'][type]
                            break
                        end
                    end
                end
#                if !hwy then pp item['tags'] end
                if not @hwy.key?(hwy) then @hwy[hwy] = 1 else @hwy[hwy] += 1 end
            end
        end
        @scale = [100/(@bbox[2]-@bbox[0]), 100/(@bbox[3]-@bbox[1])]
        @xlate = [-1*@bbox[0], -1*@bbox[1]]

        out = $stdout #File.open("test.jscad","w")

        out.write( 
<<INITCODE
function main() {
  var cube = CSG.cube({center:[0,0,-1],radius:[50,50,1.01]}); 
  var bounds = CSG.cube({center:[0,0,-1],radius:[50,50,1.01+#{lineH}]});
  var w=#{lineW}, h=#{lineH}, f=8; 
  return bounds.intersect(cube.union([
INITCODE
            )
        @ways.each do |id, way|
            if way['nodes'].length < 2 then next end
            if not way.key?('tags') then next end
            if not way['tags'].key?('highway') then next end
            pts = []
            way['nodes'].each do |nodeid|
                pts << scaleNode(@nodes[nodeid]) if @nodes.key?(nodeid)
            end
#            if pts.length <= 1 then
#                puts("Short way?")
#                pp pts
#            end
            if pts.length > 1 then
                out.write("new CSG.Path2D(/*way:#{id}*/#{pts},false).rectangularExtrude(w,h,f,false),") 
            end
        end
        out.write("]));");
        out.write("}");


#        pp @bbox
#        pp @coords
#        pp @hwy
    end

    def scaleNode(node)
        return scale(node['lat'],node['lon'])
    end


    def scale(lat,lon)
        return [(lat+@xlate[0])*@scale[0]-50, 50-(lon+@xlate[1])*@scale[1]]
    end

    def geocodeLocation(loc, radius)
        md5 = Digest::MD5.hexdigest("#{loc} #{radius}")
        cache = "cache/#{md5}.js"
        if File.exist?(cache) then
            data = JSON.parse(File.open(cache,"r").read)
        else
            url="https://maps.googleapis.com/maps/api/geocode/json"
            params={:address => loc, :key => apikey}
            uri = self.uri(url, params)
    #        pp uri
            res = Net::HTTP.get_response(uri)
    #        pp res
            if(res.code.to_i != 200) then
                raise "Error code: #{res.code}! #{res.message}"
            end
            File.open(cache,"w").write(res.body)
            data = JSON.parse(res.body)
        end
#        pp data
        pos = data['results'][0]['geometry']['location']
        self.coords = locationToBounds(pos['lat'], pos['lng'], radius)
#        pp @coords
    end

    def degToRad(deg)
        deg * Math::PI / 180.0
    end

    def radToDeg(rad)
        rad * 180.0 / Math::PI
    end

    def locationToBounds(lat, lon, dist)
        earth = 6371000.0
        d = dist
        r = earth

        lat = degToRad(lat)
        lon = degToRad(lon)

        lat1 = Math.asin( Math.sin(lat) * Math.cos(d/r) + 
                         Math.cos(lat) * Math.sin(d/r) * Math.cos(degToRad(0)) )

        lon1 = lon + Math.atan2(Math.sin(degToRad(270))*Math.sin(d/r)*Math.cos(lat),
                                         Math.cos(d/r)-Math.sin(lat)*Math.sin(lat))

        lat2 = Math.asin( Math.sin(lat) * Math.cos(d/r) + 
                         Math.cos(lat) * Math.sin(d/r) * Math.cos(degToRad(180)) )

        lon2 = lon + Math.atan2(Math.sin(degToRad(90))*Math.sin(d/r)*Math.cos(lat),
                                         Math.cos(d/r)-Math.sin(lat)*Math.sin(lat))

        return [lat1, lon1, lat2, lon2].map(&method(:radToDeg))
    end
end

cgi = CGI.new()

osm = OSM.new()

osm.geocodeLocation(cgi['location'], cgi['radius'].to_f)

osm.loadData(cgi['width'].to_f, cgi['height'].to_f)

