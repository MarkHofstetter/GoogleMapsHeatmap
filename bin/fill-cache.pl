use strict;
use warnings;
use Slurp;
use Data::Dumper;

my @lines  = slurp($ARGV[0]);

my $max;

foreach (@lines) {
  chomp;
  my @c = split / /;
  print "@c \n";  
}

# print Dumper $max;



