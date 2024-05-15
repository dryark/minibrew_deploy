#!/usr/bin/perl -w
# Copyright (c) 2024 Dry Ark LLC
use strict;
use FindBin qw($RealBin);

my $libabs = "$RealBin/lib";
my $binabs = "$RealBin/bin";

opendir( my $dh, "pkgs" );
my @files = readdir( $dh );
closedir( $dh );

for my $file ( @files ) {
    next if( $file =~ m/^\.+$/ );
    next if( $file =~ m/~$/ );
    #next if( $file eq 'lib' );
    my $full = "pkgs/$file";
    next if( ! -d $full );
    handle_dir( $full );
}

sub handle_dir {
    my $dir = shift;
    
    opendir( my $dh, "./$dir" ) or die "Could not open ./$dir";
    my @files = readdir( $dh );
    closedir( $dh );
    
    for my $file ( @files ) {
        next if( $file =~ m/^\.+$/ );
        if( $file =~ m/^[0-9\.\_]+$/ ) {
            #print "$dir/$file\n";
            my $bindir = "$dir/$file/bin";
            if( -e $bindir ) {
                #print "$libdir\n";
                handle_bin( $bindir );
            }
        }
    }
}

sub handle_bin {
    my $bindir = shift;
    my @bins;
    bin_rec( $bindir, "", \@bins );
    for my $bin ( @bins ) {
        my $rel = $bin->{rel};
        my $full = $bin->{full};
        
        
        my $symlink = "bin/$rel";
        if( -e $symlink ) {
            unlink $symlink;
        }
        
        my $dest = "../$full";
        #if( -l $full ) {
        #    my $dest2 = readlink( $full );
        #    my $pathToFull = $full;
        #    $pathToFull =~ s|/[^/]+||;
        #    my $newDest = "../$pathToFull/$dest2";
        #    $dest = $newDest;
        #}
        #print "$rel -> $dest\n";
        
        if( $rel eq 'python3' ) {
            symlink( $dest, "bin/python3-real" );
            open( my $fh, ">bin/python3" );
            print $fh "#!/bin/bash\n".
                "export PYTHONHOME=$libabs/pythonHome\n".
                "exec $binabs/python3-real \"\$\@\"\n";
            close( $fh );
            chmod 0755, "bin/python3";
        }
        else {
            symlink( $dest, $symlink );
        }
    }
}

sub bin_rec {
    my ( $abs, $rel, $res ) = @_;
    opendir( my $dh, $abs );
    my @files = readdir( $dh );
    closedir( $dh );
    
    for my $file ( @files ) {
        next if( $file =~ m/^\.+$/ );
        my $full = "$abs/$file";
        if( -d $full ) {
            #dylib_rec( $full, $rel ? "$rel/$file" : "$file", $res );
        }
        elsif( -x $full ) {
            push( @$res, {
                full => $full,
                rel => ( $rel ? "$rel/$file" : "$file" ),
            } );
        }
    }
}