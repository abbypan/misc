#!/usr/bin/perl 
#===============================================================================
#        USAGE:  ./dzs.pl -w [作者] -b [书名] -o [TXT路径]
#  DESCRIPTION:  将TXT转成HTML
#       AUTHOR:  Abby Pan (USTC), abbypan@gmail.com
#      CREATED:  2011年02月02日 13时13分18秒
#===============================================================================
use strict;
use warnings;

use utf8;

use File::Find::Rule;
use Getopt::Std;

use Encode;
use Encode::Detect::CJK qw/detect/;
#use Encode::HanExtra;

use vars qw/$LOCALE $CSS $CHAP_REGEX $writer $book $obj/;

#不缓冲直接输出
$| = 1;

#本地编码处理
$LOCALE = $^O eq 'MSWin32' ? 'cp936' : 'utf8';
binmode( STDIN,  ":encoding($LOCALE)" );
binmode( STDOUT, ":encoding($LOCALE)" );
binmode( STDERR, ":encoding($LOCALE)" );

my %opt;
getopt( 'wbor', \%opt );
( $writer, $book, $obj, $CHAP_REGEX ) = @opt{ 'w', 'b', 'o', 'r' };

print_usage() unless ( defined $obj );
$CSS = read_css();

#读入匹配各章节标题的正则表达式
$CHAP_REGEX =
  $CHAP_REGEX
  ? decode( $LOCALE, $CHAP_REGEX )
  : read_chapter_regex();

txt2html( $writer, $book, $obj );

sub print_usage {
    print <<__USAGE;
dzs - 简单的电子书工具，支持将TXT转换成HTML

用法：
dzs -w [作者] -b [书名] -o [TXT文件或目录]

参数： 
-w：指定作者名
-b: 指定书名
-f：指定txt添加的目标html文件
-o: 指定文本来源(可以是单个目录或文件)
-r: 指定分割章节的正则表达式(例如："第[ \\t\\d]+章")

举例：
由txt生成html：dzs -w 顾漫 -b 何以笙箫默 -o hy1.txt,hy2.txt,dir1 -r "第[ \\t\\d]+章"
__USAGE
    exit;
} ## end sub print_usage

sub read_css {
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

sub read_chapter_regex {

    #指定分割章节的正则表达式

    #序号
    my $r_num =
qr/[\d０１２３４５６７８９零○〇一二三四五六七八九十百千]+/;
    my $r_split = qr/[上中下]/;
	my $r_not_chap_head = qr/楔子|尾声|内容简介|正文|番外|终章|序言|后记|文案/;

    #第x章，卷x，第x章(大结局)，尾声x
    my $r_head = qr/(卷|第|$r_not_chap_head)?/;
    my $r_tail  = qr/(章|卷|回|部|折)?/;
    my $r_post  = qr/([\s\-\(\/（]+.{0,35})?/;
    my $regex_a = qr/(【?$r_head\s*$r_num\s*$r_tail$r_post】?)/;

    #(1)，(1)xxx
    #xxx(1)，xxx(1)yyy
    #(1-上|中|下)
    my $regex_b_index = qr/[(（]$r_num[）)]/;
    my $regex_b_tail  = qr/$regex_b_index\s*\S+/;
    my $regex_b_head  = qr/\S+\s*$regex_b_index.{0,10}/;
    my $regex_b_split = qr/[(（]$r_num[-－]$r_split[）)]/;
    my $regex_b = qr/$regex_b_head|$regex_b_tail|$regex_b_index|$regex_b_split/;

    #1、xxx，一、xxx
    my $regex_c = qr/$r_num[、.．].{0,10}/;

    #第x卷 xxx 第x章 xxx
    #第x卷/第x章 xxx
    my $regex_d = qr/($regex_a(\s+.{0,10})?){2}/;

	#后记 xxx
	my $regex_e = qr/(【?$r_not_chap_head\s*$r_post】?)/;

	#总体
    my $chap_r = qr/^\s*($regex_a|$regex_b|$regex_c|$regex_d|$regex_e)\s*$/m;

    return $chap_r;

} ## end sub read_chapter_regex

sub txt2html {
    ### 指定作者名，小说名，文本对象，最后生成单一的html
    my ( $writer, $book, $obj ) = @_;

    $writer = decode( $LOCALE, $writer );
    $book   = decode( $LOCALE, $book );
    my $title = $writer . "《" . $book . "》";

    print "\r开始读入: $title\n";
    my ( $toc_ref, $content_ref ) = read_chapters($obj);
    my $file = encode( $LOCALE, "$writer-$book.html" );
    gen_html( $title, $$toc_ref, $content_ref, $file );
    print "\r完成转换: $title\n";
} ## end sub txt2html

sub read_chapters {
    my ($obj) = @_;
    my @dirs = split( ',', $obj );
    my @txts = sort File::Find::Rule->file()->in(@dirs);

    my @data;
    for my $txt (@txts) {
        my $single_data = read_single_txt($txt);
        push @data, @$single_data;
    } ## end for my $txt (@txts)

    my $toc;
    my $content;
    my $i = 1;
    for my $r (@data) {
        my ( $t, $c ) = @$r;
        my ( $r_t, $r_c ) = make_single_chapter( $i++, $t, $c );
        $toc     .= $r_t;
        $content .= $r_c;
    } ## end for my $r (@data)

    return ( \$toc, \$content );
}

sub read_single_txt {

    #读入单个txt文件
    my ($txt) = @_;
    print "\r读入文件：", decode( $LOCALE, $txt ), "\n";

    my $charset = detect_file_charset($txt);
    open my $sh, "<:encoding($charset)", $txt;

    my @data;
    my ( $single_toc, $single_content ) = ( '', '' );

    #第一章
    while (<$sh>) {
        next unless /\S/;
        $single_toc = /$CHAP_REGEX/ ? $1 : $_;
        last;
    } ## end while (<$sh>)

    #后续章节
    while (<$sh>) {
        next unless /\S/;
        if ( my ($new_single_toc) = /$CHAP_REGEX/ ) {
            if ( $single_toc =~ /\S/ and $single_content =~ /\S/s ) {
                push @data, [ $single_toc, $single_content ];
                $single_toc = '';
            } ## end if ( $single_toc =~ /\S/...)
            $single_toc .= $new_single_toc . "\n";
            $single_content = '';
        }
        else {
            $single_content .= $_;
        } ## end else [ if ( my ($new_single_toc...))]
    } ## end while (<$sh>)
    push @data, [ $single_toc, $single_content ];
    return \@data;
} ## end sub read_single_txt

sub detect_file_charset {
    my ($file) = @_;
    open my $fh, '<', $file;
    read $fh, my $text, 360;
    return detect($text);
} ## end sub detect_file_charset

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
    my ( $title, $toc, $chap_html, $file ) = @_;

    print "\n写入文件：", decode( $LOCALE, $file ), "\n";
    ( my $head_title = $title ) =~ s/<.*?>//g;

    open my $fh, '>:utf8', $file;
    print $fh <<__HTML__;
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.0 Transitional//EN">
<html>
<head>
<title> $head_title </title>
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

