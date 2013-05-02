#!/usr/bin/perl
use utf8;
use strict;
use warnings;
use HTML::TreeBuilder;
use HTML::FormatText;
use Encode;
use File::Slurp qw/slurp write_file/;

#本地编码处理
our $LOCALE = $^O eq 'MSWin32' ? 'cp936' : 'utf8';
binmode( STDIN,  ":encoding($LOCALE)" );
binmode( STDOUT, ":encoding($LOCALE)" );
binmode( STDERR, ":encoding($LOCALE)" );

#目标txt文件的编码
our $DST_CHARSET= 'utf8';

my ($file) = @ARGV;
unless(-f $file){
    print "please input one file\n";
    exit;
}

conv_html_to_txt($file);

sub conv_html_to_txt {
     my ($f) = @_;
     return unless($f=~/\.html$/);
    (my $txt_file = $f)=~s/.html$/.txt/;
    print "\r生成电子书：", decode($LOCALE, "$f -> $txt_file"), "\n";
    my $html = decode('utf8', slurp($f));
    my $tree = HTML::TreeBuilder->new_from_content($html);
    my $formatter = HTML::FormatText->new(leftmargin => 0, rightmargin => 50);
    write_file($txt_file,encode($DST_CHARSET,$formatter->format($tree)));
    return $txt_file;
}

