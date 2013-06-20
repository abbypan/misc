#!/usr/bin/perl 
use strict;
use warnings;
my ($dir) = @ARGV;
my @zips = glob("$dir/*.zip");
system("perl load_xs.pl $_") for @zips;
unlink @zips;
