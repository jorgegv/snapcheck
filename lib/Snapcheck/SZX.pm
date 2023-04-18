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

use Compress::Zlib qw( uncompress );

# Functions to read and decode a SZX (zx-state) file
# Reference: https://www.spectaculator.com/docs/zx-state/intro.shtml

# read_szx_file: reads a snapshot file, returns a hashref with:
#   header: a hashref with the decoded SZX header
#   blocks: a listref to all decoded SZX data blocks
#   data: hashref of special decoded data returned for convenience:
#     machine: 16K, 48K, 128K, PLUS2, etc.
#     ram_pages: listref of binary contents of each RAM page, in order
#     mapped_page_no: number of mapped page at 0xC000, on 128K models
#     ram: full binary RAM contents (0x4000-0xFFFF).  Addresses above 0xC000
#          contain the relevant page data according to mapped_page_no
#
sub szx_read_file {
    my $filename = shift;
    my @blocks;

    open my $szx, $filename or
        die "Could not open $filename for reading\n";
    binmode $szx;

    # read initial file header
    my $header = szx_read_zxstate_header( $szx );
    defined( $header )  or
        die "ZX-state initial record not found, is this really a .SZX file?\n";

    # read all data blocks
    my $block;
    while ( $block = szx_read_block( $szx ) ) {
        push @blocks, szx_decode_block( $block );
    }
    close $szx;

    my $snap = {
        header	=> $header,
        blocks	=> \@blocks,
    };

    # gather interesting information together and add them under 'data' key
    $snap->{'data'} = szx_process_blocks( $snap );

    return $snap;
}

# reads and decodes the main file header - 8 bytes
sub szx_read_zxstate_header {
    my $f = shift;
    my $data;
    if ( read( $f, $data, 8 ) == 8 ) {
        my ( $magic, $major, $minor, $machine, $flags ) = unpack('A4CCCC', $data );
#        printf "magic=%s, major=0x%02x, minor=0x%02x, machine=0x%02x, flags=0x%02x\n", $magic, $major, $minor, $machine, $flags;
        if ( $magic eq 'ZXST' ) {
            return {
                magic		=> $magic,
                major		=> $major,
                minor		=> $minor,
                machine_id	=> $machine,
                flags		=> $flags,
            };
        }
    }
    return undef;
}

# reads a block
# returns a hashref:
#   id: 4 byte block identifier
#   size: payload size
#   rawdata: binary data
#
sub szx_read_block {
    my $f = shift;
    my $header;
    my $data;

    if ( read( $f, $header, 8 ) == 8 ) {
        my ( $id, $size ) = unpack( 'A4L', $header );
        if ( defined( $id ) and defined( $ size ) ) {
            if ( read( $f, $data, $size ) == $size ) {
                return {
                    id		=> $id,
                    size	=> $size,
                    rawdata	=> $data,
                };
            }
        }
    }

    return undef;
}

# block decoding functions:
#
# sub szx_decode_block_XXXX {
#     my $block = shift;
#     # ...return decoded data as hashref
#     return { };
# }

sub szx_decode_block_Z80R {
    my $block = shift;
    my $data;
    @{ $data }{ qw( af bc de hl af1 bc1 de1 hl1 ix iy sp pc i r iff1 iff2 im cycle_start hold_int_req_cycles flags memptr) } 
        = unpack( 'SSSSSSSSSSSSCCCCCLCCS', $block->{'rawdata'} );
    return $data;
}

sub szx_decode_block_SPCR {
    my $block = shift;
    my $data;
    @{ $data }{ qw( border port_7ffd port_1ffd port_fe reserved ) } = unpack( 'CCCCL', $block->{'rawdata'} );
    return $data;
}

sub szx_decode_block_RAMP {
    my $block = shift;
    my $data;
    @{ $data }{ qw( flags page_no ) } = unpack( 'SC*', $block->{'rawdata'} );

    my @data_bytes = unpack( 'xxxC*', $block->{'rawdata'} );	# skip first 3 bytes
    my $data_bytes = pack('C*', @data_bytes );

    if ( $data->{'flags'} == 1 ) {
        # page data is compressed
        $data->{'is_compressed'}++;
        $data->{'compressed_bytes'} = $data_bytes;
        $data->{'compressed_size'} = length( $data_bytes );

        my $uncompressed_bytes = uncompress( $data_bytes );
        if ( defined( $uncompressed_bytes ) ) {
            $data->{'bytes'} = $uncompressed_bytes;
            $data->{'size'} = length( $uncompressed_bytes );
        } else {
            $data->{'size'} = 0;
            warn "Warning: error decompressing data\n";
        }
    } else {
        # page data is uncompressed
        $data->{'bytes'} = $data_bytes;
        $data->{'size'} = length( $data_bytes );
    }
    return $data;
}

# decode a block
# enriches the original block with decoded data in 'data' key
my %decode_function = (
    'Z80R'	=> \&szx_decode_block_Z80R,
    'SPCR'	=> \&szx_decode_block_SPCR,
    'RAMP'	=> \&szx_decode_block_RAMP,
);

sub szx_decode_block {
    my $block = shift;
    if ( exists( $decode_function{ $block->{'id'} } ) ) {
        $block->{'data'} = $decode_function{ $block->{'id'} }( $block );
    }
    return $block;
}

# process the list of blocks and enrich with processed data
my %id_to_machine = (
    0  => '16K',
    1  => '48K',
    2  => '128K',
    3  => 'PLUS2',
    4  => 'PLUS2A',
    5  => 'PLUS3',
    6  => 'PLUS3E',
    7  => 'PENTAGON128',
    8  => 'TC2048',
    9  => 'TC2068',
    10 => 'SCORPION',
    11 => 'SE',
    12 => 'TS2068',
    13 => 'PENTAGON512',
    14 => 'PENTAGON1024',
    15 => 'NTSC48K',
    16 => '128KE',
);
sub szx_process_blocks {
    my $snap = shift;
    my $data;

    # machine id from header
    my $machine = ( exists( $id_to_machine{ $snap->{'header'}{'machine_id'} } ) ?
        $id_to_machine{ $snap->{'header'}{'machine_id'} } : 
        'unknown' );
    $data->{'machine'} = $machine;

    my @ram_pages;
    my $mapped_page_no = 0;	# default
    foreach my $block ( @{ $snap->{'blocks'} } ) {

        # page mapped at 0xC000
        if ( $block->{'id'} eq 'SPCR' ) {
            if ( grep { $_ eq $machine } qw( 128K PLUS2 PLUS2A PLUS3 PLUS3E 128KE ) ) {
                $mapped_page_no = $block->{'data'}{'port_7ffd'} & 0x07; # lowest 3 bits
            }
            $data->{'mapped_page_no'} = $mapped_page_no;
        }
        
        # RAM pages
        if ( $block->{'id'} eq 'RAMP' ) {
            $ram_pages[ $block->{'data'}{'page_no'} ] = $block->{'data'}{'bytes'};
        }

    }

    # content for each RAM page
    $data->{'ram_pages'} = \@ram_pages;

    # top memory from 0x4000 to 0xFFFF - contents over 0xC000 and above,
    # according to the currently mapped page
    # this should be exactly 49152 bytes long
    $data->{'ram'} = join( '', @ram_pages[ 5, 2, $mapped_page_no ] );

    # finally, update the main snap with the previously collected data
    $snap->{'data'} = $data;
}

1;
