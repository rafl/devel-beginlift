package Devel::BeginLift;

use strict;
use warnings;
use 5.008001;

our $VERSION = 0.01;

use vars qw(%lift);
use base qw(DynaLoader);

bootstrap Devel::BeginLift;

sub import {
  my ($class, @args) = @_;
  my $target = caller;
  $class->setup_for($target => \@args);
}

sub unimport {
  my ($class) = @_;
  my $target = caller;
  $class->teardown_for($target);
}

sub setup_for {
  my ($class, $target, $args) = @_;
  setup();
  $lift{$target}{$_} = 1 for @$args;
}

sub teardown_for {
  my ($class, $target) = @_;
  delete $lift{$target};
  teardown();
}

1;
