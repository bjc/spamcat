package SpamCat::Conf;

use IO::File;

use strict;
use warnings;

sub read {
  my ($filen) = @_;
  my %rc;

  my $fh = IO::File->new($filen) ||
    die "Couldn't open $filen for reading: $!\n";
  while (<$fh>) {
    my ($key, $val) = parse_line($_);
    if (defined $key && defined $val) {
      $rc{$key} = $val;
    }
  }
  $fh->close;

  %rc;
}

sub parse_line {
  my ($line) = @_;

  chomp $line;
  $line =~ s/(.*)#.*/$1/;
  $line =~ s/\s+$//;

  if ($line =~ /\s*([^\s]*)\s*=\s*(.*)$/) {
    my $key = lc $1;
    my $val = $2;

    if ($key eq 'domains') {
      $val =~ s/,/ /g;
      my @vals = split /\s+/, $val;
      $val = \@vals;
    }
    return ($key, $val);
  }
}

1;
