package App::FileShifter::Server;

use strict;
use warnings;

# ABSTRACT: App::FileShifter server module
# VERSION

use AE;
use AnyEvent::Socket;
use AnyEvent::Handle;
use AnyEvent::MessagePack;

sub run
{
    my ($class, $opts, $argv) = @_;

    tcp_server undef, $opts->{p}, sub {
        my ($fh, $host, $port) = @_;

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
        my $handler;
        $handler = sub {
            my ($handle, $data) = @_;
            print $data->[0],"\n";
            $handle->push_read(msgpack => $handler);
        };
        $handle->push_read(msgpack => $handler);
    };
    AE::cv->recv;
}

1;
__END__

=head1 SYNOPSIS

=head1 DESCRIPTION

=cut
