use strict;
use warnings;
use Slurp;
use Data::Dumper;

my @lines  = slurp($ARGV[0]);

my $max;

foreach (@lines) {
  chomp;
  my @c = split / /;
  $max->[$c[2]] |= 0;
  $max->[$c[2]] = $max->[$c[2]] < $c[3] ? $c[3] : $max->[$c[2]];
}

for (my $i = 0; $i <= scalar @$max; $i++) {
  my $mv = $max->[$i] ? $max->[$i] : 0;
  printf "%s => %s,\n", $i, $mv;
}

