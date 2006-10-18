######################################################################
# Test suite for Gaim::Log::Parser
# by Mike Schilli <cpan@perlmeister.com>
######################################################################

use warnings;
use strict;

use Log::Log4perl qw(:easy);
#Log::Log4perl->easy_init($DEBUG);

my $EG = "eg";
$EG = "../eg" unless -d $EG;

use Test::More;
BEGIN { use_ok('Gaim::Log::Parser') };

plan tests => 2;

my $canned = "$EG/canned/proto/from_user/to_user/2005-10-29.230219.txt";

my $p = Gaim::Log::Parser->new(
    file      => $canned,
    time_zone => "America/Los_Angeles",
);

my $msg = $p->next_message();

my $epoch = $msg->date();
is($epoch, "1130652143", "Check Epoch in LA timezone");

$p = Gaim::Log::Parser->new(
    file      => $canned,
    time_zone => "America/Chicago",
);

$msg = $p->next_message();
$epoch = $msg->date();
is($epoch, "1130644943", "Check Epoch in Chicago timezone");
