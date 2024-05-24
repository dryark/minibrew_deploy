#!/usr/bin/perl -w
# Copyright (c) 2024 Dry Ark LLC
use strict;
use FindBin qw($RealBin);
use lib 'mod';
use Util qw/files_in_dir find_in_dir_x/;

my $libabs = "$RealBin/lib";
my $binabs = "$RealBin/bin";

for my $pkgDir ( files_in_dir( "pkgs" ) ) {
    next if( $pkgDir =~ m/~$/ );
    my $full = "pkgs/$pkgDir";
    next if( ! -d $full );
    handle_dir( $full );
}

sub handle_dir {
    my $dir = shift;
    for my $versionDir ( files_in_dir( "./$dir" ) ) {
        if( $versionDir =~ m/^[0-9\.\_]+$/ ) {
            #print "$dir/$file\n";
            my $bindir = "$dir/$versionDir/bin";
            handle_bindir( $bindir ) if( -e $bindir );
        }
    }
}

sub handle_bindir {
    my $bindir = shift;
    for my $bin ( find_in_dir_x( $bindir, "x", 0 ) ) {
        my $rel = $bin->{rel};
        
        my $symlink = "bin/$rel";
        unlink $symlink if( -e $symlink );
        
        my $dest = "../" . $bin->{full};
        
        if( $rel eq 'python3' ) {
            symlink( $dest, "bin/python3-real" );
            open( my $fh, ">bin/python3" );
            print $fh "#!/bin/bash\n".
                "export PYTHONHOME=$libabs/pythonHome\n".
                "exec $binabs/python3-real \"\$\@\"\n";
            close( $fh );
            chmod 0755, "bin/python3";
            next;
        }
        symlink( $dest, $symlink );
    }
}