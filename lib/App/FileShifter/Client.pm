package App::FileShifter::Client;

use strict;
use warnings;

# ABSTRACT: App::FileShifter client module
# VERSION

use AE;
use AnyEvent::Socket;
use AnyEvent::Handle;
use AnyEvent::MessagePack;

sub run
{
    my ($class, $opts, $argv) = @_;

    tcp_connect $opts->{H}, 0 + $opts->{p}, sub {
        my ($fh) = @_ or die "Connect failed: $!";

        my $handle;
        $handle = AnyEvent::Handle->new(
            fh => $fh,
            on_error => sub {
                AE::log error => $_[2];
                $_[0]->destroy;
            },
            on_eof => sub {
                $handle->destroy; # destroy handle
                AE::log info => "Done.";
            });
        my $call; $call = sub {
            my $w; $w = AE::timer 1, 0, sub {
                $handle->push_write(msgpack => [list => [[], []]]);
                undef $w;
                $call->();
            };
        };
        $call->();
    };
    AE::cv->recv;
}

1;
__END__

=head1 SYNOPSIS

=head1 DESCRIPTION

=cut
