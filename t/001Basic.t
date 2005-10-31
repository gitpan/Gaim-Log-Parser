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

use Test::More qw(no_plan);
BEGIN { use_ok('Gaim::Log::Parser') };

my $p = Gaim::Log::Parser->new(
    file => "$EG/canned/proto/from_user/to_user/2005-10-29.230219.txt");

my $msg = $p->next_message();

isa_ok($msg, "Gaim::Log::Message", "Gaim::Log::Message object");
is($msg->from(), "from_user", "from_user");
is($msg->to(), "to_user", "to_user");
is($msg->protocol(), "proto", "protocol");
is($msg->content(), "quack", "content");

$msg = $p->next_message();
isa_ok($msg, "Gaim::Log::Message", "Gaim::Log::Message object");
is($msg->from(), "from_user", "from_user");
is($msg->to(), "to_user", "to_user");
is($msg->protocol(), "proto", "protocol");
is($msg->content(), "back", "content");

$msg = $p->next_message();
is($msg->content(), "a\ni\nj", "multi-line content");

$msg = $p->next_message();
is($msg->content(), "reply", "content");
is($msg->from(), "to_user", "to_user sends");

$msg = $p->next_message();
is($msg->from(), "chat_user", "chat_user sends");
