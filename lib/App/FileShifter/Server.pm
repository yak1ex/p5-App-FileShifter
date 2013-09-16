package App::FileShifter::Server;

use strict;
use warnings;

# ABSTRACT: App::FileShifter server module
# VERSION

use AE;
use AnyEvent::Socket;
use AnyEvent::Handle;
use AnyEvent::MessagePack;
use AnyEvent::Digest;

use Digest::SHA qw(sha1);
use File::Find;
use Fcntl qw(:seek);

my %dispatch = (
    list => \&_list,
    get => \&_get,
    complete => \&_complete,
    hash => \&_hash,
);

sub _list
{
    my ($opts, undef, $path, $filter) = @_;
    my $cv = AE::cv;
    my @result;
    foreach my $p (@$path) {
        find({
            wanted => sub {
                return if ! -f $File::Find::name;
                return if grep { $File::Find::name =~ /$_/ } @$filter;
                push @result, [$File::Find::name, (stat $File::Find::name)[7,9]];
            }, no_chdir => 1 }, $p);
    }
    $cv->send(\@result);
    return $cv;
}

sub _get
{
    my ($opts, undef, $file, $from, $size) = @_;
    my $cv = AE::cv;
    open my $fh, '<:raw', $file;
    my $dat;
    seek $fh, $from, SEEK_SET;
    read $fh, $dat, $size;
    close $fh;
    $cv->send([$dat, sha1($dat)]);
    return $cv;
}

sub _complete
{
    my ($opts, undef, $file, $sha1) = @_;
    my $cv = AE::cv;
    my $ctx = AnyEvent::Digest->new('Digest::SHA', opts => [1]);
    $ctx->addfile_async($file)->cb(sub {
        if(shift->recv->digest eq $sha1) {
            unlink $file;
            $cv->send([1]);
        } else {
            $cv->send([0]);
        }
    });
    return $cv;
}

sub _hash
{
    my $cv = AE::cv;
    _get(@_)->cb(sub {
        $cv->send([shift->recv->[1]]); # sha1
    });
    return $cv;
}

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
            if(exists $dispatch{$data->[0]}) {
                $opts->{v} and print STDERR $data->[0],"\n";
                $dispatch{$data->[0]}->($opts, @$data)->cb(sub {
                    $handle->push_write(msgpack => shift->recv);
                });
            } else {
                warn "Unknown command $data->[0]";
            }
            $handle->push_read(msgpack => $handler);
        };
        $handle->push_read(msgpack => $handler);
    };
    AE::cv->recv;
}

1;
__END__

=head1 SYNOPSIS

  my %opts;
  getopts(Getopt::Config::FromPod->string, \%opts);
  App::FileShifter::Server->run(\%opts, \@ARGV);

=head1 DESCRIPTION

Server-side implementation for App::FileShifter. This is a simple TCP RPC server.

=method run(\%opts, \@ARGV)

Run server mode.
Arguments are a hash reference to hold parsing result of options and an array reference of other arguments.

=cut
