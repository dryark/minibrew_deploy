#!/usr/bin/perl -w
# Copyright (c) 2024 Dry Ark LLC
use strict;
use lib 'mod';
use Ujsonin;
use Data::Dumper;

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

my $lastPercent = -1;

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
  Ujsonin::init();
  my $data = read_file("dlinfo.json");
  my $data2 = read_file("dlsize.json");
  my $root = Ujsonin::parse( $data, 0 );
  my $root2 = Ujsonin::parse( $data2, 0 );
  #print Dumper( $root );
  
  my $curlVersion = get_curl_version();
  
  my $pkgs = $root->{pkgs};
  my $shas = $root2->{sha256};
  
  #my $totSize = 0;
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
  print "Total size of packages to download: $totSize\n";
  print "Downloading raw brew packages...\n";
  print_progress( 0 );

  #exit;
  
  for my $pkg ( @$pkgs ) {
      my $name = $pkg->{name};
      my $url = $pkg->{url};
      my $plats = $pkg->{platforms};
      my $sha = $plats->{ $plat } || $plats->{all};
      my $size = $shas->{ $sha };
      #print "$name - $sha\n";
      $dlTot += $size;
      ghcr_dl( "$url$sha", "bottle/$name.tar.gz", $curlVersion, $size );
      #delete $plats->{_parent};
      #print Dumper( $plats );
  }
  print "\n";
  #print "\nDl tot: $dlTot\n";
}

sub get_curl_version {
  my $curlInfo = `curl --version`;
  my @curlLines = split("\n",$curlInfo);
  my $curlVersion = "8.4.0";
  if( $curlLines[0] =~ m/curl ([0-9\.]+)/ ) {
    $curlVersion = $1;
  }
  return $curlVersion;
}

sub ghcr_dl {
  my ( $url, $out, $curlVersion, $size ) = @_;
  #my $ua = '--user-agent "Homebrew/4.2.20 (Macintosh; Intel Mac OS X 13.6.4) curl/'.$curlVersion.'"';
  #my $lang = '--header Accept-Language:\\ en';
  #my $auth = '--header "Authorization: Bearer QQ=="';
  #my $fixed = "--disable --cookie /dev/null --globoff --show-error $ua $lang --fail --retry 3 $auth --remote-time";
  
  if( ! -e "$out" ) {
    #`curl $fixed --location $url -o $out`;
    #print "  curl $fixed --location $url -o $out\n";
    
    #my $fileDone = 0;
    #for( my $i=0;$i<5000;$i++ ) {
    #  $fileDone += 20000;
    #  last if( $fileDone >= $size );
    #  $doneSize += 20000;
    #  print_progress( int( ($doneSize/$totSize)*100 ) );
    #  select(undef, undef, undef, 0.001);
    #}
    
    my $cmd = "./curlprog \"$url\" \"$out\"";
    open my $cmdfh, '-|', $cmd;
    while( my $line = <$cmdfh> ) {
      my $bytes = int( $line );
      if( $bytes ) {
        $doneSize += $bytes;
        print_progress( int( ($doneSize/$totSize)*100 ) );
      }
      else {
        print "Line: $line\n";
      }
    }
  }
}

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

sub read_file {
    my $fn = shift;
    open my $fh, '<', $fn or return "";
    my $data = do { local $/; <$fh> };
    close( $fh );
    return $data;
}
