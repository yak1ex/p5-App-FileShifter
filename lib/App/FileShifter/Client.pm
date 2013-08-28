package App::FileShifter::Client;

use strict;
use warnings;

# ABSTRACT: App::FileShifter client module
# VERSION

use AE;
use AnyEvent::Socket;
use AnyEvent::Handle;
use AnyEvent::MessagePack;

use Data::Dumper;

my @tmpl = (
    [list => ['/tmp'], ['screen']],
    [get => '/tmp/_rebase5.14.2.lst', 0, 13042],
    [complete => '/tmp/_rebase5.14.2.lst', pack('H*', '5473535d2b9a10f00061c0e1708409390245d901')],
    [hash => '/tmp/_rebase5.14.2.lst', 0, 13042],
);

sub run
{
    my ($class, $opts, $argv) = @_;

    my $cv = AE::cv;
    $cv->begin;
    for my $i (1..$opts->{n}) {
        $cv->begin;
        tcp_connect $opts->{H}, 0 + $opts->{p}, sub {
            my ($fh) = @_ or die "Connect failed: $!";

            my $handle;
            $handle = AnyEvent::Handle->new(
                fh => $fh,
                on_error => sub {
                    AE::log error => $_[2];
                    $_[0]->destroy;
                    $cv->end;
                },
                on_eof => sub {
                    $handle->destroy; # destroy handle
                    AE::log info => "Done.";
                    $cv->end;
                });
            my $count = 0; # TENTATIVE IMPLEMENTATION
            my $call; $call = sub {
                $cv->end and return if $count++ > 5;
                my $w; $w = AE::timer 1, 0, sub {
                    $handle->push_write(msgpack => $tmpl[($i + $count) % @tmpl]);
                    $handle->push_read(msgpack => sub {
print Dumper($_[1]);
                    });
                    undef $w;
                    $call->();
                };
            };
            $call->();
        };
    }
    $cv->end;
    $cv->recv;
}

1;
__END__

=head1 SYNOPSIS

=head1 DESCRIPTION

=cut
