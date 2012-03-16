use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'ModelSeedApi',
    AUTHOR              => q{YOUR NAME <youremail@example.com>},
    VERSION_FROM        => 'lib/ModelSeedApi.pm',
    ABSTRACT            => 'YOUR APPLICATION ABSTRACT',
    ($ExtUtils::MakeMaker::VERSION >= 6.3002
      ? ('LICENSE'=> 'perl')
      : ()),
    PL_FILES            => {},
    PREREQ_PM => {
        'Dancer'                => 1.3072,
        'Exporter'              => 0,
        'HTTP::Async'           => 0,
        'HTTP::Request::Common' => 0,
        'LWP::UserAgent'        => 0,
        'Moose'                 => 0,
        'Module::Refresh'       => 0,
        'Test::More'            => 0,
        'Time::HiRes'           => 0,
        'YAML'                  => 0,

        },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'ModelSeedApi-*' },
);
