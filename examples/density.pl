use strict;
use warnings;
use Slurp;
use Data::Dumper;

my @lines  = slurp($ARGV[0]);

my $max;

# densitylog:  x y z pointcount: 283 176 9 1


foreach (@lines) {
  chomp;
  my @c = /\d+\s+\d+\s(\d+)\s+(\d)/;
  $max->[$c[0]] |= 0;
  $max->[$c[0]] = $max->[$c[0]] < $c[1] ? $c[1] : $max->[$c[0]];
}

for (my $i = 0; $i <= scalar @$max; $i++) {
  my $mv = $max->[$i] ? $max->[$i] : 0;
  printf "%s => %s,\n", $i, $mv;
}

