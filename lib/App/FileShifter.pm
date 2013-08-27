package App::FileShifter;

use strict;
use warnings;

# ABSTRACT: Placeholder for App::FileShifter
# VERSION

1;
__END__

=head1 SYNOPSIS

This module is not intended to be used.

=head1 DESCRIPTION

App::FileShifter is a utility to move files from remote host.
Files in spcified folders at server side are transferred to local side automatically
and remote files are removed
after the transfer is completed and the local file integrity is checked.

This module itself has no implementation.
It is a placeholder to describe interface between L<App::FileShifter::Server>
and L<App::FileShifter::Client>.
For actual implementation, see the above 2 modules.

The interface consists of commands from client to server.
Its serialization is done by L<AnyEvent::MessagePack>.

=head1 COMMANDS

The current considered commands are as follows:

=head2 [[$filename, $size, $date], ...] = list([[$path, ...], [$filter, ...]])

=head2 [$data, $sha1] = get([$filename, $from, $to])

=head2 [$status] = complete([$filename, $sha1])

=head2 [$sha1] = hash([$filename, $from, $to])

=cut
