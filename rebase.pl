#!/usr/bin/perl -w
# Copyright (c) 2024 Dry Ark LLC
use strict;
use FindBin qw($RealBin);

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
        $fileob = { imports => [] };
        $files{ $file } = $fileob;
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
    next if( -l $file );
    #print "File:$file\n";
    
    my $ob = $files{$file};
    my $imports = $ob->{imports};
    my @changes;
    for my $import ( @$imports ) {
        my $rep = $import;
        $rep =~ s|.+/(.+)$|$1|;
        my $rep1 = $rep;
        
        $rep = "$libabs/$rep";
        
        push( @changes, "-change \"$import\" \"$rep\"" );
        check_lib_existence( $rep1, $import );
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

sub print_progress {
    my ($percent) = @_;
    $percent *= 1.08;
    $percent = 100 if( $percent > 100 );
    my $num_blocks = int($percent / 2);
    my $bar = '[' . '=' x $num_blocks . ' ' x (50 - $num_blocks) . ']';
    printf("\r%s %3d%%", $bar, $percent);
    STDOUT->flush(); # Flush the output buffer to update the display immediately
}