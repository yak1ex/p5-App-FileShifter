# NAME

App::FileShifter - Placeholder for App::FileShifter

# VERSION

version v0.0.0

# SYNOPSIS

This module is not intended to be used.

# DESCRIPTION

App::FileShifter is a utility to move files from remote host.
Files in spcified folders at server side are transferred to local side automatically
and remote files are removed
after the transfer is completed and the local file integrity is checked.

This module itself has no implementation.
It is a placeholder to describe interface between [App::FileShifter::Server](http://search.cpan.org/perldoc?App::FileShifter::Server)
and [App::FileShifter::Client](http://search.cpan.org/perldoc?App::FileShifter::Client).
For actual implementation, see the above 2 modules.

The interface consists of commands from client to server.
Its serialization is done by [AnyEvent::MessagePack](http://search.cpan.org/perldoc?AnyEvent::MessagePack).

# COMMANDS

The current considered commands are as follows:

## \[\[$filename, $size, $date\], ...\] = list(\[\[$path, ...\], \[$filter, ...\]\])

## \[$data, $sha1\] = get(\[$filename, $from, $size\])

## \[$status\] = complete(\[$filename, $sha1\])

## \[$sha1\] = hash(\[$filename, $from, $size\])

# AUTHOR

Yasutaka ATARASHI <yakex@cpan.org>

# COPYRIGHT AND LICENSE

This software is copyright (c) 2013 by Yasutaka ATARASHI.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.
