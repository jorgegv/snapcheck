#!/usr/bin/perl
################################################################################
##
## RAGE1 - Retro Adventure Game Engine, release 1
## (c) Copyright 2020 Jorge Gonzalez Villalonga <jorgegv@daikon.es>
## 
## This code is published under a GNU GPL license version 3 or later.  See
## LICENSE file in the distribution for details.
## 
################################################################################

use strict;
use warnings;
use utf8;

# reads address symbols from a Z88DK mapfile
sub mapfile_load_address_symbols {
    my $file = shift;
    my $symbols;

    open MAP, $file or
        die "Could not open $file for reading\n";

    while ( my $line = <MAP> ) {
        if ( $line =~ m/^([\w_]+)\s+=\s+\$([[:xdigit:]]+)\s+;\s+addr,/ ) {
            $symbols->{ $1 } = hex( $2 );
        }
    }

    close MAP;

    return $symbols;
}

1;
