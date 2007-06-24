use Devel::BeginLift 'foo';

use vars qw($int);

BEGIN { $int = 1 }

sub foo { warn "foo: $_[0]\n"; $int++; 4; }

sub bar { warn "bar: $_[0]\n"; }

warn "yep\n";

warn foo("foo");

warn bar("bar");

warn "yep2: $int\n";

no Devel::BeginLift;

foo();
