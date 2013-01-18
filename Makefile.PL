use strict;
use warnings;

use ExtUtils::MakeMaker 6.30;

my %WriteMakefileArgs = (
  'ABSTRACT' => 'generate a density map (aka heatmap) overlay layer for Google Maps',
  'AUTHOR' => 'Mark Hofstetter <cpan@trust-box.at>',
  'BUILD_REQUIRES' => {
    'Test::More' => '0',
  },
  'CONFIGURE_REQUIRES' => {
    'ExtUtils::MakeMaker' => '6.30'
  },
  'DISTNAME' => 'Geo::Heatmap',
  'EXE_FILES' => [],
  'LICENSE' => 'perl',
  'NAME' => 'Geo::Heatmap',
  'PREREQ_PM' => {
    'Moose'         => '2.0604',
    'Image::Magick' => '6.77',  
    'CHI'           => '0.56',
  },
  'VERSION' => '0.06',
  'test' => {
    'TESTS' => 't/*.t'
  }
);

WriteMakefile(%WriteMakefileArgs);

