#!/usr/bin/perl -w
# Copyright (c) 2024 Dry Ark LLC
use strict;
use Cwd qw/getcwd/;
use File::Path qw/make_path/;
use lib 'mod';
use Util qw/print_progress bytesToHR files_in_dir/;

my $bottleDir = glob( "~/.minibrew/cache" );

# This guesses the size of the extracted files based on the uncompressed
# size of the tarball. This is not exact because there is overhead in the tarball
# for each file entry, but it is close enough and can be done quickly.
# Why do we need to figure out this size? Well to show a nice progress bar during
# extraction of course!

# Do we need the extracted size to show progress? Couldn't we just use the progress
# through the archive while incrementally going through it? Well we could... I just
# ended up doing it this way because I was initially trying to use existing tools
# to get a nice progress and tracking the size of the files being created as they
# were created. That didn't work and I ended up implementing it myself.
# End result? Wasting time and computing energy decompressing the files twice. :shrug:

my ( $totXSize, $totSize, $files ) = size_of_tarballs( $bottleDir );
print "Total extracted size: ".bytesToHR( $totXSize )."\n";

print "Extracting packages...\n";
my $doneSize = 0;
print_progress( 0 );
my $cwd = getcwd();
for my $file ( @$files ) {
    next if( $file !~ m/\.tar\.gz$/ );
    
    open( my $pipe, "./tarball_incremental \"$bottleDir/$file\" \"$cwd/pkgs\" |" );
    my $prev = '';
    while( my $line = <$pipe> ) {
        $doneSize += $line;
        print_progress( int( ($doneSize/$totXSize)*100 ) );
    }
    close( $pipe );
}
print_progress( 100 );
print "\nDone extracted size: ".bytesToHR( $doneSize )."\n";

sub size_of_tarballs {
    my $dir = shift;
    my $totXSize = 0;
    my $totSize = 0;
    my @files = files_in_dir( $dir );
    for my $file ( @files ) {
        next if( $file !~ m/\.tar\.gz$/ );
        my $full = "$bottleDir/$file";
        #print "$full\n";
        $totSize += -s $full;
        my @lines = `gzip -l \"$full\"`;
        my $line = $lines[1];
        $line =~ s/^ +//;
        my @parts = split(/ +/,$line);
        $totXSize += $parts[1];
    }
    return ( $totXSize, $totSize, \@files );
}