use strict;
use warnings;
use Geo::Heatmap::USNaviguide_Google_Tiles;
use Data::Dumper;
use DBI;

my $tile = '276+177+9';

my ($x, $y, $z) = (276, 177, 9);

my $mca = printf("raw_%s_%s_%s", $x, $y, $z);

my $value = &Google_Tile_Factors($z, 0) ;

print Dumper $value;

my %r = Google_Tile_Calc($value, $y, $x);
print Dumper \%r;

my $dbh = DBI->connect("dbi:Pg:dbname=gisdb", 'gisdb', 'gisdb', {AutoCommit => 0});

my $p = get_points(\%r);

print Dumper $p;

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

