#!/usr/bin/perl 
#===============================================================================
#         FILE:  delete_xs.pl
#        USAGE:  ./delete_xs.pl  
#  DESCRIPTION:  
#       AUTHOR:  Abby Pan (USTC), abbypan@gmail.com
#      VERSION:  1.0
#      CREATED:  2011年01月10日 01时44分09秒
#===============================================================================

use strict;
use warnings;
use DBI;
use Encode;
use Data::Dumper;
our $DBH = DBI->connect('dbi:Pg:dbname=xs','xswrite','xsadmin');

my ($sql) =  @ARGV;
print "$sql\n";
my $update_book=$DBH->prepare($sql);
$update_book->execute();
