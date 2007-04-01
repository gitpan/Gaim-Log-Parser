###########################################
package Gaim::Log::Parser;
###########################################
use strict;
use warnings;
use Log::Log4perl qw(:easy);
use DateTime;
use Gaim::Log::Message;

our $VERSION = "0.03";

###########################################
sub new {
###########################################
    my($class, @options) = @_;

    my $self = {
        time_zone => DateTime::TimeZone->new(name => 'local'),
        @options,
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
                                 time_zone => $self->{time_zone},
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

###########################################
sub datetime {
###########################################
    my($self) = @_;

    return $self->{dt};
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

=head2 Methods

=over 4

=item C<my $parser = Gaim::Log::Parser->new(file =E<gt> $filename)>

Create a new log parser. 

The parser will interpret the message time stamps according to a selected
time zone.

By default, the time zone is assumed to be 'local' which will try all
kinds of tricks to determine the local time zone. If this is not what you
want, a time zone for DateTime::TimeZone can be provided, e.g.
"America/Los_Angeles".

=item C<my $msg = $parser-E<gt>next_message()>

Return the next message in the log. Returns an object of type
C<Gaim::Log::Message>. Check its documentation for details.

=item C<my $dt = $parser-E<gt>datetime()>

Retrieve the DateTime object used internally by
C<Gaim::Log::Parser>. Can be used to obtain the 
the start date of the parsed log file or the time zone used.

=head1 SEE ALSO

L<Gaim::Log::Finder>, L<Gaim::Log::Message> in this distribution

=back

=head1 LEGALESE

Copyright 2005 by Mike Schilli, all rights reserved.
This program is free software, you can redistribute it and/or
modify it under the same terms as Perl itself.

=head1 AUTHOR

2005, Mike Schilli <cpan@perlmeister.com>
