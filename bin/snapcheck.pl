#!/usr/bin/perl
################################################################################
##
## (c) Copyright 2023 ZXjogv <zx@jogv.es>
## 
## This code is published under a GNU GPL license version 3 or later.  See
## LICENSE file in the distribution for details.
## 
################################################################################
##
## snapcheck.pl: given a snapshot of a given ZX Spectrum program or game,
## ensures that a set of constraints and conditions are met by the
## snapshotted program: values in given memory positions, register ranges,
## etc.
##
## Use case: when there is a bug in a RAGE1 program, there are some things
## that always need to be right: the screen number, number of sprites,
## animation sequences, stack pointer value in range, etc.
##
## Snapshot file must be in SZX (zx-state) format.
##

use strict;
use warnings;
use utf8;
use v5.20;

use FindBin;
use lib "$FindBin::Bin/../lib";
use Data::Dumper;
use Getopt::Std;

use Snapcheck::SZX;
use Snapcheck::MapFile;
use Snapcheck::Rules;

our ( $opt_f, $opt_c, $opt_d, $opt_m );
getopts( 'f:c:dm:' );

# read snapshot data from file
my $snap_file = $opt_f;
if ( not defined( $snap_file ) ) {
    die "usage: $0 -f <snapshot_file.szx> [-d] [-c <check_rules.cfg>] [-m <mapfile>]\n";
}
my $snapshot = szx_read_file( $snap_file );

# get debug flag
my $debug = defined( $opt_d );

# if debug, report on the file
if ( $debug ) {
    print "\nSnapshot File Structure:\n";
    foreach my $block ( @{ $snapshot->{'blocks'} } ){
        printf "  [%-4s] %d bytes", $block->{'id'}, $block->{'size'};

        if ( $block->{'id'} eq 'RAMP' ) {
            printf " - Page: %d", $block->{'data'}{'page_no'};
            printf " - Size: %d bytes", $block->{'data'}{'size'};
            if ( $block->{'data'}{'is_compressed'} ) {
                printf " - Compressed size: %d bytes", $block->{'data'}{'compressed_size'};
            }
        }

        if ( $block->{'id'} eq 'SPCR' ) {
            printf " - Border: %d - Port_7ffd: 0x%02X - Port_1ffd: 0x%02X - Port_fe: 0x%02X",
                map { $block->{'data'}{ $_ } } qw( border port_7ffd port_1ffd port_fe );
        }

        if ( $block->{'id'} eq 'Z80R' ) {
            printf " - AF=0x%04X, BC=0x%04X, DE=0x%04X, HL=0x%04X, PC=0x%04X, SP=0x%04X [...]",
                map { $block->{'data'}{ $_ } } qw( af bc de hl pc sp );
        }

        print "\n";
    }
}

# if debug, dump the 48K RAM in hexdump format
if ( $debug ) {
    print "\nRAM Dump:\n";
    my @bytes = unpack( 'C*', $snapshot->{'data'}{'ram'} );
    my $address = 0x4000;
    while ( @bytes ) {
        my @line_bytes = splice( @bytes, 0, 16 );
        printf "  %04X  %s  %s\n",
            $address,
            join( ' ', map { sprintf( '%02X', $_ ) } @line_bytes ),
            join( '', map { ( ( $_ >= 32 ) and ( $_ < 127 ) ) ? chr($_) : '.' } @line_bytes );
        $address += 16;
    }
}

# if -m file was provided, load symbols from map file
my $symbols;
if ( defined( $opt_m ) ) {
    $symbols = mapfile_load_address_symbols( $opt_m );
    if ( $debug ) {
        print "\nLoaded Address Symbols:\n";
        print join( "\n", map { sprintf( '  %-30s = 0x%04X', $_, $symbols->{ $_ } ) } sort keys %$symbols ), "\n";
    }
}

# if -c file was provided, check rules in the file
my $rules_file = $opt_c;
