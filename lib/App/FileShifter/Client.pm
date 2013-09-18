package App::FileShifter::Client;

use strict;
use warnings;

# ABSTRACT: App::FileShifter client module
# VERSION

use Pod::Usage;

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

sub _make_tpath
{
    my ($dest, $target, $file) = @_;
    my $temp = $file->[0];
    $temp =~ s@^$target@@;
    return "${dest}.tmp/$temp";

}

sub _make_dpath
{
    my ($dest, $target, $file) = @_;
    my $temp = $file->[0];
    $temp =~ s@^$target@@;
    my $base = "$dest/$temp";
    return $base unless -f $base;
    my $count = 1;
    while(1) {
        my $candidate = $base.'.'.$count;
        return $candidate unless -f $candidate;
        ++$count;
    }
}

sub _update_assignment
{
    my ($assign, $list) = @_;
    my %check = map { $_ => 1 } keys %$assign;
    delete $check{$_->[0]} for @$list;
    delete $assign->{$_} for keys %check;
}

sub run
{
    my ($class, $opts, $argv) = @_;

    my ($host, $port, $number, $unit, $dest, $target, $interval, $verbose) = @{$opts}{qw(H p n u d t i v)};

    pod2usage(-verbose => 0, -msg => 'You need to specify host by -H', -exitval => 1) if ! defined $host;
    pod2usage(-verbose => 0, -msg => 'You need to specify port by -p', -exitval => 1) if ! defined $port;
    pod2usage(-verbose => 0, -msg => 'You need to specify source path by -t', -exitval => 1) if ! defined $target;
    pod2usage(-verbose => 0, -msg => 'You need to specify destination path by -d', -exitval => 1) if ! defined $dest;

    $number ||= 5;
    $unit ||= 65536;
    $interval ||= 30;

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
                _update_assignment(\%assign, $list);
                $verbose and print Dumper($list);
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
                my $file = _assign($list, \%assign);
                if(! defined $file) {
                    my $w; $w = AE::timer $interval, 0, sub { undef $w; $call->() };
                    return;
                }
                my $tpath = _make_tpath($dest, $target, $file);
                make_path(dirname($tpath));
                my $cursize = -s $tpath // 0;
                my $left = $file->[1] - $cursize;
                if($left == 0) { # maybe completed
                    $verbose and print STDERR "COMPLETE?: $file->[0]\n";
                    AnyEvent::Digest->new('Digest::SHA', opts => [1])->addfile_async($tpath)->cb(sub {
                        $handle->push_write(msgpack => [complete => $file->[0], shift->recv->digest]);
                        $handle->push_read(msgpack => sub {
                            if($_[1]) { # OK
                                my $dpath = _make_dpath($dest, $target, $file);
                                make_path(dirname($dpath));
                                rename $tpath => $dpath;
                                utime $file->[2], $file->[2], $dpath;
                            } else {
                                unlink $tpath; # Just remove currently
                                delete $assign{$file->[0]};
                            }
                            $call->();
                        });
                    });
                } else {
                    $verbose and print STDERR "GET: $file->[0]\n";
                    $handle->push_write(msgpack => [get => $file->[0], $cursize, $left > $unit ? $unit : $left]);
                    $handle->push_read(msgpack => sub {
                        if(sha1($_[1][0]) eq $_[1][1]) {
                            open my $fh, '>>:raw', $tpath;
                            print $fh $_[1][0];
                            close $fh;
                        }
                        delete $assign{$file->[0]};
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
