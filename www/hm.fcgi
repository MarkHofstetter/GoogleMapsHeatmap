#!/usr/bin/env perl

use strict;
use FCGI;
use DBI;
use CHI;
use FindBin qw/$Bin/;
use lib "$Bin/../lib";

use GoogleHeatmap;

my $cache = CHI->new( driver  => 'Memcached::libmemcached',
    servers => [ "127.0.0.1:11211" ],
);

our $dbh = DBI->connect("dbi:Pg:dbname=gisdb", 'gisdb', 'gisdb', {AutoCommit => 0});


my $request = FCGI::Request();

while ($request->Accept() >= 0) {
  my $env = $request->GetEnvironment();
  my $p = $env->{'QUERY_STRING'};
  
  my ($tile) = ($p =~ /tile=(.+)/);
  $tile =~ s/\+/ /g;
  
  # package needs a CHI Object, for caching 
  #               a Function Reference to get LatLOng within a Google Tile
  #               a config File
 
  my $ghm = GoogleHeatmap->new();
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

  $ghm->cache($cache);
  $ghm->return_points( \&get_points );
  my $image = $ghm->create_hm_tile($tile);
  
  my $length = length($image);
  
  print "Content-type: image/png\n";
  print "Content-length: $length \n\n";
  binmode STDOUT;
  print $image;
                                       
}

sub get_points {
  my $r = shift;
#  my ($latn, $lngw, $lats, $lnge) = @_;
##  my $dbh = DBI->connect("dbi:Pg:dbname=gisdb", 'gisdb', 'gisdb', {AutoCommit => 0});

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
##   $dbh->disconnect;
  return \@p;
}


__END__
select ST_AsEWKT(geom) from geodata where geom && ST_SetSRID(ST_MakeBox2D(ST_Point(48.2226, 16.34765),                     
ST_Point(48.16631, 16.4352)),4326);
           st_asewkt            
--------------------------------
 SRID=4326;POINT(48.213 16.375)
(1 row)


