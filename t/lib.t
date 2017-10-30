# -*- Mode: cperl -*-

use Test::More tests => 42;

use strict;
use warnings;

my ($tmpdir, %conf);
BEGIN {
  $tmpdir = "/tmp/spamcat.t.$$";
  %conf = (dbpath        => "$tmpdir/spamcat.sqlite3",
	   default_count => 20,
	   deliver       => "t/delivert $tmpdir",
	   domains       => ['spamcat.example.com', 'spamcat2.example.com']);

  system "rm -rf $tmpdir";
  mkdir $tmpdir;
  system "/usr/local/bin/sqlite3 $conf{dbpath} < config/create-tables.sql";
}

END {
  system "rm -rf $tmpdir";
}

require_ok 'SpamCat';

ok(SpamCat->can('new'), 'Has constructor');
my $sch = SpamCat->new(%conf);
ok(defined $sch, 'Constructor returns instance');

ok(SpamCat->can('decrement_count'), 'Has count decrementor');
is($sch->decrement_count('foo'), $conf{default_count},
   'Default count for new sender');
is($sch->decrement_count('foo'), 19, 'Existing sender decrements');

ok(SpamCat->can('get_count'), 'Has count getter');
is($sch->get_count('foo'), 19, 'Returns existing sender count');
ok(!defined $sch->get_count('doesntexist'),
   'Non-existant sender has undefined count');

ok(SpamCat->can('set_count'), 'Has count setter');
is($sch->set_count('bar', 10), 10, 'Setting count returns existing count');
is($sch->set_count('bar', 1), 1, 'Updating existing count to 1 returns 1');
is($sch->decrement_count('bar'), 0, 'Decrementing count from 1 returns 0');
is($sch->decrement_count('bar'), 0, 'Decrementing count from 0 returns 0');

ok(SpamCat->can('parse_to'));
my @addrs;
@addrs = $sch->parse_to('foo@bar.com');
is($addrs[0], 'foo@bar.com');
@addrs = $sch->parse_to('"FooBar" <foo@bar.com>');
is($addrs[0], 'foo@bar.com');
@addrs = $sch->parse_to('"Foo@Bar" <baz@pham.com>');
is($addrs[0], 'baz@pham.com');
@addrs = $sch->parse_to('"Foo@Bar" <baz@pham.com>', '"a@b <one@two.com>"');
is($addrs[0], 'baz@pham.com');
is($addrs[1], 'one@two.com');

ok(SpamCat->can('deliver'), 'Has delivery method');
test_file('foo', 1);
test_file('foo2', 1);
test_file('multiple', 1);
test_file('wrongdomain', 1);
test_file('nosubj', 1);
test_file('bar', 0);

ok(SpamCat->can('get_table'));
my @rows = @{$sch->get_table()};
is($#rows, 3);
@rows = sort { $a->{sender} cmp $b->{sender} } @rows;
is($rows[0]->{sender}, 'bar');
is($rows[0]->{count}, 0);
is($rows[1]->{sender}, 'foo');
is($rows[1]->{count}, 16);
is($rows[2]->{sender}, 'name1');
is($rows[2]->{count}, 20);
is($rows[3]->{sender}, 'nosubj');
is($rows[3]->{count}, 20);

sub test_file {
  my ($filen, $should_exist) = @_;

  my $input = IO::File->new("<t/fixtures/$filen") ||
    die "Couldn't open $filen: $!\n";
  my $inputfd = fileno($input);
  open STDIN, ">&$inputfd" || die "Couldn't open $inputfd: $!\n";

  $sch->deliver();

  if ($should_exist) {
    ok(-f "$tmpdir/$filen") || diag("$tmpdir/$filen doesn't exist.");

    local $/;
    my $fh = IO::File->new("<$tmpdir/$filen") ||
      die "Couldn't open $tmpdir/$filen for reading: $!\n";
    my $got = <$fh>;
    $fh->close;

    $fh = IO::File->new("<t/fixtures/$filen.expected") ||
      die "Couldn't open t/fixtures/$filen.expected for reading: $!\n";
    my $expected = <$fh>;
    $fh->close;

    is($got, $expected) || diag("Test for $filen output failed.");
  } else {
    ok(! -f "$tmpdir/$filen") || diag("$tmpdir/$filen exists.");
  }
}
