###########################################
package Gaim::Log::Message;
###########################################
use strict;
use warnings;

our $VERSION = "0.01";
our @ACCESSORS = qw(from to protocol date content);

###########################################
sub new {
###########################################
    my($class, %options) = @_;

    my $self = {
        %options,
    };

    $class->make_accessor($_) for @ACCESSORS;

    bless $self, $class;
}

##################################################
sub make_accessor {
##################################################
    my($package, $name) = @_;

    no strict qw(refs);

    my $code = <<EOT;
        *{"$package\\::$name"} = sub {
            my(\$self, \$value) = \@_;
    
            if(defined \$value) {
                \$self->{$name} = \$value;
            }
            if(exists \$self->{$name}) {
                return (\$self->{$name});
            } else {
                return "";
            }
        }
EOT
    if(! defined *{"$package\::$name"}) {
        eval $code or die "$@";
    }
}

###########################################
sub as_string {
###########################################
    my($self) = @_;

    return "$self->{from} =($self->{protocol})=> $self->{to}: [" .
           scalar(localtime($self->{date})) . "] [$self->{content}]";
}

1;

__END__

=head1 NAME

Gaim::Log::Message - Represents a logged Gaim message

=head1 SYNOPSIS

    use Gaim::Log::Message;

=head1 DESCRIPTION

Gaim::Log::Message blah blah blah.

=head1 EXAMPLES

  $ perl -MGaim::Log::Message -le 'print $foo'

=head1 LEGALESE

Copyright 2005 by Mike Schilli, all rights reserved.
This program is free software, you can redistribute it and/or
modify it under the same terms as Perl itself.

=head1 AUTHOR

2005, Mike Schilli <cpan@perlmeister.com>
