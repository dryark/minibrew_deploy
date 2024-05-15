#!/usr/bin/perl -w
use strict;

system("./dl.pl");
system("./extract.pl");
system("./genlib.pl");
system("./genbin.pl");
system("./rebase.pl");
print "DONE\n";