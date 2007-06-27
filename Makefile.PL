use inc::Module::Install 0.67;

name 'Devel-BeginLift';
license 'perl';
author 'Matt S Trout';
all_from 'lib/Devel/BeginLift.pm';

makemaker_args(XS => { 'lib/Devel/BeginLift.xs' => 'lib/Devel/BeginList.c' });

WriteMakefile;
