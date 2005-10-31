###########################################
package Gaim::Log::Parser;
###########################################
use strict;
use warnings;
use Log::Log4perl qw(:easy);
use DateTime;
use Gaim::Log::Message;

our $VERSION = "0.01";

###########################################
sub new {
###########################################
    my($class, @options) = @_;

    my $self = {
        @options 
    };

    LOGDIE "Cannot open $self->{file}" unless -f $self->{file};

    open my $fh, "$self->{file}" or 
        LOGDIE "Cannot open $self->{file}";

        # "Conversation with foo at 2005-10-29 23:02:19 
        #  on bar (protocol)"
    my $first_line = <$fh>;

    $self->{fh} = $fh;

    DEBUG "Parsing logfile $self->{file}";

        # ./proto/from/to/2005-10-29.230219.txt
    if($self->{file} =~ m#([^/]+)/([^/]+)/([^/]+)/([^/]+)$#) {
        $self->{protocol} = $1;
        $self->{from}     = $2;
        $self->{to}       = $3;
        if($4 =~ /(\d{4})-(\d{2})-(\d{2})\.(\d{2})(\d{2})(\d{2})/) {
          my $dt = DateTime->new(year => $1, month  => $2, day    => $3,
                                 hour => $4, minute => $5, second => $6,
                                 #time_zone => 'America/Los_Angeles',
                                 time_zone =>
                                   DateTime::TimeZone->new(name => 'local'),
                                );
          $self->{dt}         = $dt;
        }
    } else {
        LOGDIE "Please use full path information (something like ",
               "\".../proto/from/to/2005-10-29.230219.txt\")",
               " since ", __PACKAGE__, " uses it to generate meta data ",
               "from it.";
    }

    bless $self, $class;

    if($self->{offset}) {
            # If an offset has been specified, leap ahead message
            # by message (therefore accounting for roll-overs) until
            # the requested offset has been reached.
        my $offset = $self->{offset};
        $self->{offset} = tell $self->{fh};
        while($offset > $self->{offset}) {
            $self->next_message() or last;
        }
    } else {
        $self->{offset} = tell $self->{fh};
    }

    return bless $self, $class;
}

###########################################
sub next_message {
###########################################
    my($self) = @_;

    my $fh = $self->{fh};
    my $line_match = qr/^\((\d{2}:\d{2}:\d{2})\) (.*)/;

        # Read next line
    my $line = <$fh>;

        # End of file?
    if(! defined $line) {
        DEBUG "End of file $self->{file}";
        $self->{fh} = $fh;
        return undef;
    }

    my($date, $msg);

        # Valid line?
    if($line =~ /$line_match/) {
        $date = $1;
        $msg  = $2;
    } else {
        while(defined $line and $line !~ /$line_match/) {
            chomp $line;
            LOGWARN "Format error in $self->{file}: ",
                    "Line '$line' doesn't match $line_match";
            $line = <$fh>;
        }
    }

    $self->{offset} = tell $fh;

        # We've got a message, let's see if there's continuation lines
    while(defined($_ = <$fh>)) {
        if(/$line_match/) {
                # Next line doesn't look like a continuation line,
            last;
        }
            # We have a continuation line.
        chomp; $msg .= "\n$_"; $self->{offset} = tell $fh; }

        # Go back to the previous offset, before we tried searching
        # for continuation lines
    seek $fh, $self->{offset}, 0;

    $self->{fh} = $fh;

        # Check if we have a roll-over
    my $dtclone = $self->{dt}->clone();

    my($hour, $minute, $second) = split /:/, $date;
    $dtclone->set_hour($hour);
    $dtclone->set_minute($minute);
    $dtclone->set_second($second);

    if($dtclone->epoch() < $self->{dt}->epoch()) {
        # Rollover detected. Adjust datetime instance variable
        $self->{dt}->add(days => 1);
        $dtclone->add(days => 1);
    }

    my $sender   = $self->{from};
    my $receiver = $self->{to};

        # strip "from_user: " from beginning of message
    if($msg =~ /(.*?): /) {
        if($1 eq $receiver) {
                # The other party sent
            ($sender, $receiver) = ($receiver, $sender);
        } elsif($1 ne $sender) {
                # A different chat user sent
            $sender = $1;
        }
        $msg =~ s/(.*?): //g;
    } else {
            # No sender specified. This could be a message like
            # "foo logged out.". Leave sender/receiver as is.
    }

    DEBUG "Creating new message (date=",  $dtclone->epoch(), ") msg=",
          $msg;

    return Gaim::Log::Message->new(
            from     => $sender,
            to       => $receiver,
            protocol => $self->{protocol},
            content  => $msg,
            date     => $dtclone->epoch(),
    );
}

###########################################
sub offset {
###########################################
    my($self) = @_;

    return $self->{offset};
}

1;

__END__

=head1 NAME

Gaim::Log::Parser - Parse Gaim's Log Files

=head1 SYNOPSIS

    use Gaim::Log::Parser;

    my $parser = Gaim::Log::Parser->new(file => $filename);

    while(my $msg = $parser->next_message()) {
        print $msg->as_string();
    }

=head1 DESCRIPTION

Gaim::Log::Parser parses Gaim's log files. In the 1.4+ series, they are 
organized in the following way:

    .gaim/logs/protocol/local_user/comm_partner/2005-10-29.230219.txt

=head1 EXAMPLES

  $ perl -MGaim::Log::Parser -le 'print $foo'

=head1 LEGALESE

Copyright 2005 by Mike Schilli, all rights reserved.
This program is free software, you can redistribute it and/or
modify it under the same terms as Perl itself.

=head1 AUTHOR

2005, Mike Schilli <cpan@perlmeister.com>
