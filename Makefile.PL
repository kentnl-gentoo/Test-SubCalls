use inc::Module::Install;

name           ( 'Test-SubCalls'                    );
abstract       ( 'Test the number of times a subroutine is called' );
author         ( 'Adam Kennedy <cpan@ali.as>'       );
version_from   ( 'lib/Test/SubCalls.pm'             );
license        ( 'perl'                             );
requires       ( 'perl'                  => '5.006' );
requires       ( 'Test::More'            => '0.60'  );
requires       ( 'File::Spec'            => '0.80'  );
requires       ( 'Hook::LexWrap'         => '0.20'  );
build_requires ( 'Test::Builder::Tester' => '1.01'  );
include        ( 'Test::Builder::Tester'            );
auto_install   ();

&WriteAll;
