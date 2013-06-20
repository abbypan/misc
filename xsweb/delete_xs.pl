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

my ($bookname) =  @ARGV;
our $DBH = DBI->connect('dbi:Pg:dbname=xs','xswrite','xsadmin');
my $sql=$bookname=~/^\d+$/?qq[select writer_id, id from book where id= ? ;]:qq[select writer_id, id from book where name ~ ?;];
my $row_ary  = $DBH->selectall_arrayref($sql, undef, $bookname);
if(scalar(@$row_ary)!=1){
    print Dumper($row_ary);
    die "有多本书符合条件,退出!";
}

my $writer_id = $row_ary->[0][0];
my $book_id = $row_ary->[0][1];

print "delete chapter\n";
my $del_chap=$DBH->prepare(qq[delete from chapter where book_id = ?]);
$del_chap->execute($book_id);

print "delete book\n";
my $del_book=$DBH->prepare(qq[delete from book where id = ?]);
$del_book->execute($book_id);

print "delete writer\n";
my $del_writer= $DBH->prepare(qq[delete from writer where id not in (select distinct writer_id from book);]);
$del_writer->execute();
