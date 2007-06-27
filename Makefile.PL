use inc::Module::Install 0.67;

name 'Devel-BeginLift';
all_from 'lib/Devel/BeginLift.pm';

build_requires 'Test::More';

WriteMakefile(
  dist => {
    PREOP => 'pod2text lib/Devel/BeginLift.pm >$(DISTVNAME)/README'
  }
);
