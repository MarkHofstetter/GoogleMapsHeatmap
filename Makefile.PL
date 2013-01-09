use strict;
use warnings;
use ExtUtils::MakeMaker 6.58;
my $from = 'lib/Geo/Heatmap.pm';
WriteMakefile(
    ABSTRACT_FROM      => $from,
    AUTHOR             => 'Mark Hofstetter <mh@univie.ac.at>',
    CONFIGURE_REQUIRES => { 'ExtUtils::MakeMaker' => '6.58' },
    EXE_FILES          => [],
    LICENSE            => 'perl',
    NAME               => 'Geo::Heatmap',
    PREREQ_PM          => {
        'CHI'              => '0',
        'Exporter'         => '0',
        'Graphics::Magick' => '0',
        'Math::Trig'       => '0',
        'Moose'            => '0',
        'Storable'         => '0',
        'Test::Most'       => '0',
    },
    VERSION_FROM => $from,
    test         => { TESTS => 't/*.t' }
);
