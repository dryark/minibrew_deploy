#!/usr/bin/perl -w
# Copyright (c) 2024 Dry Ark LLC

# This finds all of the dylib and so files within the packages that contain
# dynamic library loads starting with the placeholder HOMEBREW_ markers.
# It replaces those with full paths to the actual libraries being loaded.
# It's also possible to just remove the paths entirely and then use
# DYLD_LIBRARY_PATH pointing to the constructed lib folder, but it's a small
# bit more convenient not to have to use that ENV var.
# Plus, it replicates what brew itself actually does.

use strict;
use FindBin qw($RealBin);
use lib 'mod';
use Util qw/print_progress/;

my $libabs = "$RealBin/lib";

my $arch = `uname -m`;
$arch =~ s/\n//;

my $install_name_tool = "install_name_tool";
if( ! -e "/usr/bin/install_name_tool" ) {
    $install_name_tool = "./install_name_tool";
}

my @lines = `./scan pkgs test share`;
my %files;
my $fileob;
for my $line ( @lines ) {
    if( $line =~ m/^File:(.+)/ ) {
        my $file = $1;
        #print "File:$file\n";
        $files{ $file } = $fileob = { imports => [] };
        next;
    }
    if( $line =~ m/^ *LC_LOAD_DYLIB:(.+)/ ) {
        my $import = $1;
        push( @{ $fileob->{imports} }, $import );
    }
}

my $count = keys %files;
my $done = 0;
my %checked;
print "Files to rebase: $count\n";
print_progress(0);

for my $file ( sort keys %files ) {
    next if( -l $file ); # Won't happen now that ./scan is used
    #print "File:$file\n";
    
    my @changes;
    for my $import ( @{$files{$file}->{imports}} ) {
        my $justFile = $import;
        $justFile =~ s|.+/(.+)$|$1|;
        
        push( @changes, "-change \"$import\" \"$libabs/$justFile\"" );
        check_lib_existence( $justFile, $import );
    }
    my $change = join( ' ', @changes );
    #print "$install_name_tool $change \"$file\"\n";
    `$install_name_tool $change \"$file\" 2>/dev/null`;
    if( $arch eq 'arm64' ) {
        `codesign --sign - --force --preserve-metadata=entitlements,requirements,flags,runtime \"$file\" 2>/dev/null`;
    }
    $done++;
    print_progress( int( ($done/$count)*100 ) );
}
print_progress( 100 );
print "\n";

sub check_lib_existence {
    my ( $file, $import ) = @_;
    return if( $checked{ $file } );
    $checked{ $file } = 1;
    if( ! -e "lib/$file" ) {
        if( $import =~ m/\@\@HOMEBREW_CELLAR\@\@(.+)/ ) {
            my $dest = "../pkgs$1";
            #print "Missing lib/$file -> $dest\n";
            symlink( $dest, "lib/$file" );
        }
    }
}