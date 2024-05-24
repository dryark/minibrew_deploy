# Copyright (c) 2024 Dry Ark LLC
package Util;
use strict;
use warnings;
use Exporter qw/import/;

our @EXPORT_OK = qw/read_file bytesToHR print_progress find_in_dir files_in_dir find_in_dir_x/;

my $lastPercent = -1;

sub print_progress {
    my ($percent) = @_;
    return if( $percent == $lastPercent );
    $percent *= 1.08;
    $percent = 100 if( $percent > 100 );
    my $num_blocks = int($percent / 2);
    my $bar = '[' . '=' x $num_blocks . ' ' x (50 - $num_blocks) . ']';
    printf("\r%s %3d%%", $bar, $percent);
    STDOUT->flush(); # Flush the output buffer to update the display immediately
    $lastPercent = $percent;
}

sub bytesToHR {
    my $bytes = shift;
    if( $bytes > ( 1024 * 1024 ) ) {
        my $num = int( $bytes / ( 1024 * 1024 ) * 100 ) / 100;
        return "${num} mb";
    }
    if( $bytes > 1024 ) {
        my $num = int( $bytes / ( 1024 ) * 100 ) / 100;
        return "${num} kb";
    }
    return "${bytes} b";
}

sub read_file {
    my $fn = shift;
    open my $fh, '<', $fn or return "";
    my $data = do { local $/; <$fh> };
    close( $fh );
    return $data;
}

sub find_in_dir {
    return find_in_dir_x( @_, 1 );
}

sub find_in_dir_x {
    my ( $dir, $regex, $recurse ) = @_;
    my @res;
    files_rec( glob( $dir ), "", \@res, $regex, $recurse );
    return @res;
}

sub files_rec {
    my ( $abs, $rel, $res, $regex, $recurse ) = @_;
    
    for my $file ( files_in_dir( $abs ) ) {
        my $full = "$abs/$file";
        if( -d $full ) {
            files_rec( $full, $rel ? "$rel/$file" : "$file", $res, $regex, 1 ) if( $recurse );
        }
        elsif(
            ( $regex eq 'x' && -x $full ) ||
            $file =~ m/$regex/
        ) {
            push( @$res, {
                full => $full,
                rel => ( $rel ? "$rel/$file" : "$file" ),
            } );
        }
    }
}

sub files_in_dir {
    my $dir = shift;
    opendir( my $dh, $dir );
    my @files = readdir( $dh );
    closedir( $dh );
    
    my @filesout;
    for my $file ( @files ) {
        next if( $file =~ m/^\.+$/ );
        push( @filesout, $file );
    }
    return @filesout;
}

1;