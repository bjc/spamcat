package SpamCat;

use Carp;
use Data::Dumper;
use DBI;
use Email::Simple;
use IO::File;

use strict;
use warnings;

our $VERSION = '0';

my $log = sub {
  print STDERR "DEBUG: " . join(', ', @_) . "\n";
};

sub new {
  my($class, %conf) = @_;

  my $dbh = DBI->connect("dbi:SQLite:dbname=$conf{dbpath}", '', '');
  $conf{dbh} = $dbh;
  bless \%conf, $class;
}

sub deliver {
  my ($self) = @_;

  local $/;
  my $email = Email::Simple->new(<>);
  my $email_to = $email->header('To');
  my @to_addrs = $self->parse_to(split /,\s*/, $email_to);

  my $count;
  foreach my $to_addr (@to_addrs) {
    foreach my $domain (@{$self->{domains}}) {
      if ($to_addr =~ /(.*)\@$domain/) {
	my $sender = $1;
	my $c = $self->decrement_count($sender);
	if (!defined $count || $c > $count) {
	  $count = $c;
	}
      }
    }
  }

  if (defined $count) {
    return if $count == 0;

    my $count_str = '[' . $count . '/' . $self->{default_count} . ']';
    my $new_subject = $email->header('Subject');
    if ($new_subject) {
      $new_subject .= ' - ' . $count_str;
    } else {
      $new_subject = $count_str;
    }
    $email->header_set('Subject' => $new_subject);
  }

  my $deliverfh = IO::File->new("| " . $self->{deliver}) ||
    die "Couldn't open pipe to " . $self->{deliver} . ": $!\n";
  print $deliverfh $email->as_string;
  $deliverfh->close;
}

sub parse_to {
  my ($self, @tovals) = @_;

  map {
    if ($_ =~ /<(.*)>/) {
      $1;
    } else {
      $_;
    }
  } @tovals;
}

sub get_table {
    my ($self) = @_;

    $self->in_transaction(sub { $self->get_table_t() });
}

sub get_count {
  my ($self, $sender) = @_;

  $self->in_transaction(sub { $self->get_count_t($sender) });
}

sub set_count {
  my ($self, $sender, $count) = @_;

  $self->in_transaction(sub { $self->set_count_t($sender, $count); });
}

sub decrement_count {
  my ($self, $sender) = @_;

  $self->in_transaction(sub { $self->decrement_count_t($sender); });
}

#
# The _t functions are meant to be run inside transacitons.
#

sub get_table_t {
    my ($self) = @_;

    my @rows;
    my $q = 'SELECT * FROM emails';
    my $sth = $self->{dbh}->prepare($q);
    $sth->execute();
    while (my $row = $sth->fetchrow_hashref) {
	push @rows, $row
    }
    if ($sth->err) {
	$sth->finish;
	carp $sth->errstr;
	return;
    }
    $sth->finish;

    \@rows;
}

sub get_count_t {
  my ($self, $sender) = @_;

  my $q = 'SELECT count FROM emails WHERE sender=?';
  my $sth = $self->{dbh}->prepare($q);
  $sth->execute($sender);
  my @row = $sth->fetchrow_array;
  $sth->finish;

  $row[0];
}

sub set_count_t {
  my ($self, $sender, $count) = @_;

  my $q;
  if (!defined $self->get_count_t($sender)) {
    # Insert when there's no count.
    $q = 'INSERT INTO emails (count, sender) VALUES (?, ?)';
  } else {
    # Otherwise update the record with the new count.
    $q = 'UPDATE emails SET count = ?, modified = CURRENT_TIMESTAMP WHERE sender = ?'
  }
  my $sth = $self->{dbh}->prepare($q);
  $sth->execute($count, $sender);
  $sth->finish;

  $count;
}

sub decrement_count_t {
  my ($self, $sender) = @_;

  my $q;
  my $count = $self->get_count_t($sender);
  if (!defined $count) {
    $count = $self->{default_count};
    $q = 'INSERT INTO emails (count, sender) VALUES (?, ?)';
  } else {
    $count = $count <= 0 ? '0' : $count - 1;
    $q = "UPDATE emails SET count = ?, modified = CURRENT_TIMESTAMP WHERE sender = ?";
  }

  my $sth = $self->{dbh}->prepare($q);
  $sth->execute($count, $sender);
  $sth->finish;

  $count;
}

sub in_transaction {
  my ($self, $sub) = @_;

  $self->{dbh}->begin_work;
  my $rc = eval { &$sub($self); };
  if ($@) {
    $self->{dbh}->rollback;
    carp "Transaction failed: $@\n";
  } else {
    $self->{dbh}->commit;
  }

  $rc;
}

1;
