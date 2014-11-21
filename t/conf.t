# -*- mode: cperl -*-

use Test::More tests => 7;

use strict;
use warnings;

require_ok 'SpamCat::Conf';

ok(SpamCat::Conf->can('read'));
my %conf = SpamCat::Conf::read('t/fixtures/sample.conf');
ok(%conf);

is($conf{dbpath}, '/tmp/spamcat.sqlite3');
is($conf{default_count}, 10);
is($conf{deliver}, 't/delivert');
is_deeply($conf{domains},
	  ['spamcat.example.com', 'spamcat2.example.com', 'spamcat3']);
