use ExtUtils::MakeMaker;

my $VERSION = 0.01;


WriteMakefile(
    'NAME'          => 'DB::Introspector',
    'VERSION'  =>  $VERSION,
    'PREREQ_PM' => {
        'Config::Properties' => 0.56,
        'Devel::Symdump'     => 1.00,
        'IO::File'           => 1.00,
        'DBI'                => 1.00,
        'Test::Unit'         => 0
      },
);
