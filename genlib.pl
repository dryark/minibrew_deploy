#!/usr/bin/perl -w
# Copyright (c) 2024 Dry Ark LLC
use strict;
use lib 'mod';
use Util qw/files_in_dir find_in_dir/;

for my $pkgDir ( files_in_dir( "pkgs" ) ) {
    next if( $pkgDir =~ m/~$/ );
    my $pkgDirFull = "pkgs/$pkgDir";
    print "$pkgDirFull $pkgDir\n";
    next if( ! -d $pkgDirFull );
    handle_dir( $pkgDirFull, $pkgDir );
}

sub handle_dir {
    my ( $dir, $pkg ) = @_;
    
    for my $versionDir ( files_in_dir( "./$dir" ) ) {
        if( $versionDir =~ m/^[0-9\.\_]+$/ ) {
            #print "$dir/$file\n";
            my $libdir = "$dir/$versionDir/lib";
            if( -e $libdir ) {
                #print "$libdir\n";
                handle_libdir( $libdir );
            }
            
            if( $pkg =~ m/^python/ ) {
                if( $versionDir =~ m/^([0-9]+)\.([0-9]+)/ ) {
                    my $twoParts = "$1.$2";
                    my $pyHome = "../$dir/$versionDir/Frameworks/Python.framework/Versions/$twoParts";
                    symlink( $pyHome, "lib/pythonHome" );
                }
            }
        }
    }
}

sub handle_libdir {
    my $libdir = shift;
    print "libdir:$libdir\n";
    #exit 0;
    for my $dy ( find_in_dir( $libdir, qw/\.dylib$/ ) ) {
        my $symlink = "lib/" . $dy->{rel};
        unlink $symlink if( -e $symlink );
        symlink( "../" . $dy->{full}, $symlink );
    }
}