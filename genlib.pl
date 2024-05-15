#!/usr/bin/perl -w
# Copyright (c) 2024 Dry Ark LLC
use strict;

opendir( my $dh, "pkgs" );
my @files = readdir( $dh );
closedir( $dh );

for my $file ( @files ) {
    next if( $file =~ m/^\.+$/ );
    next if( $file =~ m/~$/ );
    next if( $file eq 'lib' );
    my $full = "pkgs/$file";
    next if( ! -d $full );
    handle_dir( $full, $file );
}

sub handle_dir {
    my ( $dir, $pkg ) = @_;
    
    opendir( my $dh, "./$dir" ) or die "Could not open ./$dir";
    my @files = readdir( $dh );
    closedir( $dh );
    
    for my $file ( @files ) {
        next if( $file =~ m/^\.+$/ );
        if( $file =~ m/^[0-9\.\_]+$/ ) {
            #print "$dir/$file\n";
            my $libdir = "$dir/$file/lib";
            if( -e $libdir ) {
                #print "$libdir\n";
                handle_lib( $libdir );
            }
            
            if( $pkg =~ m/^python/ ) {
                if( $file =~ m/^([0-9]+)\.([0-9]+)/ ) {
                    my $twoParts = "$1.$2";
                    my $pyHome = "../$dir/$file/Frameworks/Python.framework/Versions/$twoParts";
                    symlink( $pyHome, "lib/pythonHome" );
                }
            }
        }
    }
}

sub handle_lib {
    my $libdir = shift;
    my @dylibs;
    dylib_rec( $libdir, "", \@dylibs );
    for my $dy ( @dylibs ) {
        my $rel = $dy->{rel};
        my $full = $dy->{full};
        
        
        my $symlink = "lib/$rel";
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
        symlink( $dest, $symlink );
    }
}

sub dylib_rec {
    my ( $abs, $rel, $res ) = @_;
    opendir( my $dh, $abs );
    my @files = readdir( $dh );
    closedir( $dh );
    
    for my $file ( @files ) {
        next if( $file =~ m/^\.+$/ );
        my $full = "$abs/$file";
        if( -d $full ) {
            dylib_rec( $full, $rel ? "$rel/$file" : "$file", $res );
        }
        elsif( $file =~ m/\.dylib$/ ) {
            push( @$res, {
                full => $full,
                rel => ( $rel ? "$rel/$file" : "$file" ),
            } );
        }
    }
}