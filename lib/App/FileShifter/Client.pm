package App::FileShifter::Client;

use strict;
use warnings;

# ABSTRACT: App::FileShifter client module
# VERSION

use AE;
use AnyEvent::Socket;
use AnyEvent::Handle;
use AnyEvent::MessagePack;
use AnyEvent::Digest;

use Digest::SHA qw(sha1);
use File::Path qw(make_path);
use File::Basename;
use Data::Dumper;

sub _connect
{
    my ($cv, $host, $port, $sub) = @_;

    tcp_connect $host, $port, sub {
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
            }
        );
        $sub->($handle);
    };
}

sub _assign
{
    my ($list, $assign) = @_;
    my @list = grep { ! exists $assign->{$_->[0]} } @$list;
    return if ! @list;
    $assign->{$list[0][0]} = 1;
    return $list[0];
}

sub run
{
    my ($class, $opts, $argv) = @_;

    my ($host, $port, $number, $unit, $dest, $target, $interval, $verbose) = @{$opts}{qw(H p n u d t i v)};
    my $list; # [[$name, $size, $date],...]
    my %assign;

    my $cv = AE::cv;
    my $cv2 = AE::cv;

    _connect($cv, $host, 0 + $port, sub {
        my $handle = shift;
        my $w; $w = AE::timer 0, $interval, sub {
            $handle->push_write(msgpack => [list => [$target], []]);
            $handle->push_read(msgpack => sub {
                $list = $_[1];
                undef %assign;
                print Dumper($list);
                $cv2->send if defined $w;
            });
        };
    });
    $cv2->recv;

    for my $i (1..$number) {
        $cv->begin;
        _connect($cv, $host, 0 + $port, sub {
            my $handle = shift;
            my $call; $call = sub {
                my $target = _assign($list, \%assign);
                if(! defined $target) {
                    my $w; $w = AE::timer 1, 0, sub { undef $w; $call->() };
                    return;
                }
                my $tpath = "${dest}.tmp/$target->[0]";
                make_path(dirname($tpath));
                my $cursize = -s $tpath // 0;
                my $left = $target->[1] - $cursize;
                if($left == 0) { # maybe completed
                    $verbose and print STDERR "COMPLETE?: $target->[0]\n";
                    AnyEvent::Digest->new('Digest::SHA', opts => [1])->addfile_async($tpath)->cb(sub {
                        $handle->push_write(msgpack => [complete => $target->[0], shift->recv->digest]);
                        $handle->push_read(msgpack => sub {
                            if($_[1]) { # OK
                                my $dpath = "$dest/$target->[0]";
                                make_path(dirname($dpath));
                                rename $tpath => $dpath;
                            } else {
                                delete $assign{$target->[0]};
                            }
                            $call->();
                        });
                    });
                } else {
                    $verbose and print STDERR "GET: $target->[0]\n";
                    $handle->push_write(msgpack => [get => $target->[0], $cursize, $left > $unit ? $unit : $left]);
                    $handle->push_read(msgpack => sub {
                        if(sha1($_[1][0]) eq $_[1][1]) {
                            open my $fh, '>>:raw', $tpath;
                            print $fh $_[1][0];
                            close $fh;
                        }
                        delete $assign{$target->[0]};
                        $call->();
                    });
                }
            };
            $call->();
        });
    }
    $cv->recv;
}

1;
__END__

=head1 SYNOPSIS

  my %opts;
  getopts(Getopt::Config::FromPod->string, \%opts);
  App::FileShifter::Client->run(\%opts, \@ARGV);

=head1 DESCRIPTION

Client-side implementation for App::FileShifter.

A loop invokes C<list> repeatedly. Other C<-n> loops invoke C<complete> or C<get> depending whether temporary size is equal to actual size or not.

=method run(\%opts, \@ARGV)

Run client mode.
Arguments are a hash reference to hold parsing result of options and an array reference of other arguments.

=cut
