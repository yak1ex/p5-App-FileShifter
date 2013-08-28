package App::FileShifter::Server;

use strict;
use warnings;

# ABSTRACT: App::FileShifter server module
# VERSION

use AE;
use AnyEvent::Socket;
use AnyEvent::Handle;
use AnyEvent::MessagePack;

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
    my @result;
    foreach my $p (@$path) {
        find({
            wanted => sub {
                return if ! -f $File::Find::name;
                return if grep { $File::Find::name =~ /$_/ } @$filter;
                push @result, [$File::Find::name, (stat $File::Find::name)[7,9]];
            }, no_chdir => 1 }, $p);
    }
    return \@result;
}

sub _get
{
    my ($opts, undef, $file, $from, $size) = @_;
    open my $fh, '<:raw', $file;
    my $dat;
    seek $fh, $from, SEEK_SET;
    read $fh, $dat, $size;
    close $fh;
    return [$dat, sha1($dat)];
}

sub _complete
{
    my ($opts, undef, $file, $sha1) = @_;
# TODO: remove actually
    return [Digest::SHA->new->addfile($file)->digest eq $sha1];
}

sub _hash
{
    return [_get(@_)->[1]]; # sha1
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
                $opts->{v} and print $data->[0],"\n";
                my $ret = $dispatch{$data->[0]}->($opts, @$data);
                $handle->push_write(msgpack => $ret);
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

=head1 DESCRIPTION

=cut
