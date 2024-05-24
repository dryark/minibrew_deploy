#!/usr/bin/perl -w
# Copyright (c) 2024 Dry Ark LLC
use strict;
use lib 'mod';
use Ujsonin;
use Util qw/print_progress bytesToHR read_file/;
use Data::Dumper;
use File::Path qw/make_path/;

my $bottleDir = glob( "~/.minibrew/cache" );
if( ! -d $bottleDir ) {
    make_path( $bottleDir );
}

my $arch = `uname -m`;
$arch =~ s/\n//;

my $macosVersion = `sw_vers -productVersion`;
my $major = $macosVersion;
$major =~ s/\..+//;

my $plat = "";#"ventura";
if( $arch eq 'arm64' ) {
  $plat = "arm64_";
}

if( $major == 12 ) { $plat .= "monterey"; }
elsif( $major == 13 ) { $plat .= "ventura"; }
elsif( $major == 14 ) { $plat .= "sonoma"; }
else {
  print "MacOS older than monterey(12) or newer than sonoma(14)\n";
  exit;
}

my $doneSize = 0;
my $totSize = 0;
my $dlTot = 0;

if( ! -e "/usr/bin/install_name_tool" ) {
  if( ! -e "./install_name_tool.tar.xz" ) {
    `curl --progress-bar --location https://github.com/dryark/cctools-port/releases/download/986/install_name_tool.tar.xz -o install_name_tool.tar.xz`;
  }
  if( ! -e "./install_name_tool" ) {
    `tar -xf install_name_tool.tar.xz`;
  }
}

download_plat( $plat );

sub download_plat {
    my $plat = shift;
    my $root  = Ujsonin::parse_file( "dlinfo.json" );
    my $root2 = Ujsonin::parse_file( "dlsize.json" );
    
    my $pkgs = $root->{pkgs};
    my $shas = $root2->{sha256};
    
    for my $pkg ( @$pkgs ) {
        my $plats = $pkg->{platforms};
        my $sha = $plats->{ $plat } || $plats->{all};
        #print "$name - $sha\n";
        my $size = $shas->{ $sha };
        if( !$size ) {
            print "Could not find size for $sha\n";
        }
        $totSize += $size;
    }
    print "Total size of packages to download: ".bytesToHR( $totSize )."\n";
    print "Downloading raw brew packages...\n";
    print_progress( 0 );
    
    for my $pkg ( @$pkgs ) {
        my $name  = $pkg->{name};
        my $plats = $pkg->{platforms};
        my $sha   = $plats->{ $plat } || $plats->{all};
        my $size  = $shas->{ $sha };
        #print "$name - $sha\n";
        $dlTot += $size;
        ghcr_dl( $pkg->{url}.$sha, "$bottleDir/$name-$sha.tar.gz", $size );
    }
    print "\n";
}

sub ghcr_dl {
    my ( $url, $out, $size ) = @_;
    
    if( ! -e "$out" ) {
        my $cmd = "./curlprog \"$url\" \"$out\"";
        open my $cmdfh, '-|', $cmd;
        while( my $line = <$cmdfh> ) {
            if( $line =~ m/^[0-9]+$/ ) {
                $doneSize += $line;
                print_progress( int( ($doneSize/$totSize)*100 ) );
                next;
            }
            print "Line: $line\n";
        }
    }
}