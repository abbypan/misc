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
use utf8;

#本地编码处理
our $LOCALE = $^O eq 'MSWin32' ? 'cp936' : 'utf8';
binmode( STDIN,  ":encoding($LOCALE)" );
binmode( STDOUT, ":encoding($LOCALE)" );
binmode( STDERR, ":encoding($LOCALE)" );
our $CSS = read_css();
our $DBH = DBI->connect( 'dbi:Pg:dbname=xs', 'xswrite', 'xsadmin' );

my ($bookname) = @ARGV;

chdir('test');
export_xs($bookname);

#my $book_id_list = $DBH->selectall_arrayref( 'select id from book' ); 
#for my $i (@$book_id_list){
##    print $i->[0], "\n";
    #export_xs($i->[0]);
#}

sub export_xs {
    my ($bookname) = @_;
    my $sql =
      $bookname =~ /^\d+$/
      ? qq[select writer_id, id from book where id= ? ;]
      : qq[select writer_id, id from book where name ~ ?;];
    my $row_ary = $DBH->selectall_arrayref( $sql, undef, $bookname );
    if ( scalar(@$row_ary) != 1 ) {
        print Dumper($row_ary);

        #    die "有多本书符合条件,退出!";
    }

    my $writer_id = $row_ary->[0][0];
    my $book_id   = $row_ary->[0][1];

    my $writer_name =
      $DBH->selectrow_arrayref( 'select name from writer where id = ?',
        undef, $writer_id );
    $writer_name = decode( 'utf8', $writer_name->[0] );
    $writer_name=~s/^\s+//;
    my $book_q = $DBH->selectrow_arrayref(
        'select name,chapter_num from book where id = ?',
        undef, $book_id );
    my $book = decode( 'utf8', $book_q->[0] );
    $book=~s/^\s+//;
    my $chapter_num = $book_q->[1];
    if($chapter_num==0){
        my $chap_q = $DBH->selectrow_arrayref(
            'select count(*) from chapter where book_id = ?',
        undef, $book_id );
        $chapter_num = $chap_q->[0];
    }
#    print $writer_id, $book_id, $writer_name, $chapter_num, $book, "\n";

    # 文件名
    my $title = $writer_name . "《" . $book . "》";
    my $file = encode( $LOCALE, "$writer_name-$book.html" );
    print "\r准备生成: $title\n";

    my $toc;
    my $content;
    for my $i ( 1 .. $chapter_num ) {
        my $temp = $DBH->selectrow_arrayref(
"select title,content from chapter where book_id= $book_id and id = ?",
            undef, $i
        );
        my ( $t, $c ) = map { decode( 'utf8', $_ ) } @$temp;
        my ( $r_t, $r_c ) = make_single_chapter( $i, $t, $c );
        $toc     .= $r_t;
        $content .= $r_c;
    }

    # 写入文件
    gen_html( $title, $toc, \$content, $file );
}

sub make_single_chapter {

    #生成单个章节
    my ( $i, $chap_t, $chap_c ) = @_;
    my $j = sprintf( "%03d# ", $i );
    print "\r正在处理第 ", $i, " 小节";

    for ($chap_c) {
        s#<br\s*/?\s*>#\n#gi;
        s#\s*(.*\S)\s*#<p>$1</p>\n#gm;
        s#<p>\s*</p>##g;
    } ## end for ($chap_c)

    $chap_t =~ s/\s+\n?$//;
    my $content = <<__FLOOR__;
<div class="floor">
<div class="fltitle">$j<a name="toc$i">$chap_t</a></div>
<div class="flcontent">$chap_c</div>
</div>
__FLOOR__

    my $toc = <<__TOC__;
<li><a href="#toc$i">$chap_t</a></li>
__TOC__

    return ( $toc, $content );
} ## end sub make_single_chapter

sub gen_html {

    # 指定标题，目录，内容，文件名，最后生成html文件
    my ( $title, $toc, $chap_html, $file ) = @_;

    print "\n写入文件：", decode( $LOCALE, $file ), "\n";

    open my $fh, '>:utf8', $file;
    print $fh <<__HTML__;
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.0 Transitional//EN">
<html>
<head>
<title> $title </title>
<meta http-equiv="content-type" content="text/html; charset=utf-8">
<style type="text/css">
$CSS
</style>
</head>
<body>
<div id="title"> $title </div>
<div id="toc"><ol>
$toc
</ol></div>
<div id="content">
$$chap_html
</div></body></html>
__HTML__
    close $fh;
} ## end sub gen_html

sub read_css {

    #指定默认样式
    my $css = <<__CSS__;
body {
	font-size: medium;
	font-family: Verdana, Arial, Helvetica, sans-serif;
	margin: 1em 8em 1em 8em;
	text-indent: 2em;
	line-height: 145%;
}
#title, .fltitle {
	border-bottom: 0.2em solid #ee9b73;
	margin: 0.8em 0.2em 0.8em 0.2em;
	text-indent: 0em;
	font-size: x-large;
    font-weight: bold;
    padding-bottom: 0.25em;
}
#title, ol { line-height: 150%; }
#title { text-align: center; }
__CSS__
    return $css;
} ## end sub read_css
