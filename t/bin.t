#!/usr/bin/perl

use Test::More tests => 1;

use IO::File;

use strict;
use warnings;

system "/usr/bin/env > /tmp/fpp";

my $spamcat  = 'bin/spamcat';
my $conffile = 't/fixtures/sample.conf';

# Add testlib which has createdb and possibly population of said db.

my @dumpconfig = `$spamcat -c t/fixtures/sample.conf --dumpconfig`;
my %got = parse_configdump(@dumpconfig);
my %expected = (DBPATH	      => '/tmp/spamcat.sqlite3',
		DEFAULT_COUNT => 10,
		DELIVER	      => 't/delivert',
		DOMAINS	      => "spamcat.example.com, spamcat2.example.com, spamcat3");
is_deeply(\%got, \%expected);

# Test for proper delivery.
my $fh = IO::File->new("|$spamcat -c $conffile") ||
  die "Couldn't open pipe to $spamcat: $!\n";
$fh->close;

sub parse_configdump {
  my %rc;

  while (my $line = shift) {
    $line =~ /(.*) = (.*)/;
    $rc{$1} = $2;
  }

  %rc;
}
