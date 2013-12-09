# NAME

Geo::Heatmap - generate a density map (aka heatmap) overlay layer for Google Maps, see the www directory in the distro how it works

see the script directory for creating a scale

for a real life example see 

http://www.trust-box.at/dev/gm/GoogleMapsHeatmap/www/GoogleMapsHeatmap.html

for Dokumentation see

http://www.trust-box.at/googlemaps-geoheatmap/

# REQUIRES

    Moose
    CHI
    Imager

# METHODS

## tile

    tile();

    return the tile image in png format

# ATTRIBUTES

    debug
    cache
    logfile
    return_points
    zoom_scale
    palette

## USAGE

Create a Heatmap layer for GoogleMaps

### The HTML part

<pre>
<code>
  &lt;head&gt;
     &lt;meta name="viewport" content="initial-scale=1.0, user-scalable=no" /&gt;
     &lt;style type="text/css"&gt;
       html { height: 100% }
       body { height: 100%; margin: 0; padding: 0 }
       \#map-canvas { height: 100% }
     &lt;/style&gt;
     &lt;script type="text/javascript"
       src="https://maps.googleapis.com/maps/api/js?key=<yourapikey>&sensor=true"&gt;
     &lt;/script&gt;
     &lt;script type="text/javascript"&gt;
       var overlayMaps = \[{
         getTileUrl: function(coord, zoom) {
           return "hm.fcgi?tile="+coord.x+"+"+coord.y+"+"+zoom;
         },
 

            tileSize: new google.maps.Size(256, 256),
            isPng: true,
            opacity: 0.4
          }];
    
          function initialize() {
            var mapOptions = {
              center: new google.maps.LatLng(48.2130, 16.375),
              zoom: 9
            };
            var map = new google.maps.Map(document.getElementById("map-canvas"),
                mapOptions);
    
          var overlayMap = new google.maps.ImageMapType(overlayMaps[0]);
          map.overlayMapTypes.setAt(0,overlayMap);
    
          }
          google.maps.event.addDomListener(window, 'load', initialize);
    
       &lt;/script&gt;
     &lt;/head&gt;
     &lt;body&gt;
       &lt;div id="map-canvas"/&gt;
    &lt;/body&gt;
  </code>
  </pre>
  <br>

### The (f)cgi part

<pre>
<code>
  \#!/usr/bin/env perl
  

    use strict;
    use FCGI;
    use DBI;
    use CHI;
    use FindBin qw/$Bin/;
    use lib "$Bin/../lib";
    
    use Geo::Heatmap;
    
    #my $cache = CHI->new( driver  => 'Memcached::libmemcached',
    #    servers    => [ "127.0.0.1:11211" ],
    #    namespace  => 'GoogleMapsHeatmap',
    #);
    
    
    my $cache = CHI->new( driver => 'File',
             root_dir => '/tmp/GoogleMapsHeatmap'
         );
    
    
    our $dbh = DBI->connect("dbi:Pg:dbname=gisdb", 'gisdb', 'gisdb', {AutoCommit => 0});
    
    my $request = FCGI::Request();
    
    while ($request->Accept() >= 0) {
      my $env = $request->GetEnvironment();
      my $p = $env->{'QUERY_STRING'};
    
      my ($tile) = ($p =~ /tile=(.+)/);
      $tile =~ s/\+/ /g;
    
      # package needs a CHI Object for caching
      #               a Function Reference to get LatLOng within a Google Tile
      #               maximum number of points per zoom level
    
      my $ghm = Geo::Heatmap->new();
      $ghm->palette('palette.store');
      $ghm->zoom_scale( {
        1 => 298983,
        2 => 177127,
        3 => 104949,
        4 => 90185,
        5 => 70338,
        6 => 37742,
        7 => 28157,
        8 => 12541,
        9 => 3662,
        10 => 1275,
        11 => 417,
        12 => 130,
        13 => 41,
        14 => 18,
        15 => 10,
        16 => 6,
        17 => 2,
        18 => 0,
      } );
    
    sub get_points {
      my $r = shift;
    
      my $sth = $dbh->prepare( qq(select ST_AsEWKT(geom) from geodata
                             where geom &&
                  ST_SetSRID(ST_MakeBox2D(ST_Point($r->{LATN}, $r->{LNGW}),
                                          ST_Point($r->{LATS}, $r->{LNGE})
                            ),4326))
                  );
    
      $sth->execute();
    
      my @p;
      while (my @r = $sth->fetchrow) {
        my ($x, $y) = ($r[0] =~/POINT\((.+?) (.+?)\)/);
        push (@p, [$x ,$y]);
      }
      $sth->finish;
      return \@p;
    }
    </code>
    </pre>

You need a color palette (one is included) to encode values to colors, in Storable Format as 
an arrayref of arrayrefs eg

    [50] = [34, 45, 56]

which means that a normalized value of 50 would lead to an RGB color of 34% red , 45% blue, 
56% green.

- zoom\_scale

    The maximum number of points for a given google zoom scale. You would be able to extract 
    to values from the denisity log or derive them from your data in some cunning way

- cache

    You need some caching for the tiles otherwise the map would be quite slow. Use a CHI object 
    with the cache you like

- return\_points

    A function reference which expects a single hashref as a parameter which defines two LAT/LONG 
    points to get all data points within this box:

          $r->{LATN}, $r->{LNGW}), $r->{LATS}, $r->{LNGE}

    The function has to return an arrayref of arrayrefs of the points within the box

- tile

    Returns the rendered image



# REPOSITORY

[https://github.com/MarkHofstetter/GoogleMapsHeatmap](https://github.com/MarkHofstetter/GoogleMapsHeatmap)

# AUTHOR

Mark Hofstetter <hofstettm@cpan.org>

    Thanks to 
    brian d foy
    Marcel Gruenauer
    David Steinbrunner

# TODO

<ul>
  <li> put more magic in calculation of zoom scales </li>
  <li> make more things configurable </li>
  <li> add even more tests </li>
</ul>

# COPYRIGHT AND LICENSE

This software is copyright (c) 2013 by Mark Hofstetter

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.
