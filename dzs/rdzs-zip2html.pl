#!/usr/bin/perl
use utf8;
use strict;
use warnings;

use Archive::Zip;
use Encode;
#use Encode::Detect::CJK qw/detect/;

#本地编码处理
our $LOCALE = $^O eq 'MSWin32' ? 'cp936' : 'utf8';
binmode( STDIN,  ":encoding($LOCALE)" );
binmode( STDOUT, ":encoding($LOCALE)" );
binmode( STDERR, ":encoding($LOCALE)" );

our $CSS = read_css();

my ($file) = @ARGV;

unless(-f $file){
    print "please input one file\n";
    exit;
}

conv_zip_to_html($file) if($file=~/\.zip$/);

sub read_css
{

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


sub conv_zip_to_html {
    my ($f) = @_;
    return unless($f=~/\.zip$/);
    my $zip = Archive::Zip->new($f);

    my $index  = $zip->contents('000.html');
    return unless ( defined $index );
    $index = decode('utf8', $index);
    my ($title) = $index=~/<div id="title">(.*?)<\/div>/s;

    my @members = $zip->membersMatching( '.*\.html' );
    @members = sort { $a->fileName() cmp $b->fileName() } @members;
    shift @members; 

    (my $html_file = $f)=~s/.zip$/.html/;
    print "\r生成电子书：", decode($LOCALE, "$f -> $html_file"), "\n";
    my $i = 1;
    my ($toc, $content);
    for my $m (@members){
        print "\r",$m->fileName();
        my $chap = decode('utf8', $m->contents());
        my ($t) =  $chap=~/id="chapter">(.*?)<\/a>/s;
        my ($c) =  $chap=~/<div id="content">(.*?)<\/div>\s+<div id="footer"/s;
        my ( $r_t, $r_c ) = make_single_chapter( $i++, $t, $c );
        $toc     .= $r_t;
        $content .= $r_c;
    }

    gen_html($title, $toc, \$content, $html_file);
    return $html_file;
}


sub make_single_chapter
{

    #生成单个章节
    my ( $i, $chap_t, $chap_c ) = @_;
    my $j = sprintf ( "%03d# ", $i );
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

sub gen_html
{

    # 指定标题，目录，内容，文件名，最后生成html文件
    my ( $title, $toc, $chap_html, $file ) = @_;

    print "\n写入文件：", decode( $LOCALE, $file ), "\n";
    (my $head_title = $title)=~s/<.*?>//g;

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

