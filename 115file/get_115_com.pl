#!/usr/bin/perl
# USAGE : perl get_115_com.pl http://u.115.com/file/f546a1622d
use version 0.2;
use LWP::Simple;
use Encode;
# version 0.2 ：关闭普通下载时，取优蛋下载地址
# version 0.1 : 取普通下载的地址

my ($url) = @ARGV;

get_one_file($url);

sub get_one_file {
 my ($url) = @_;

 my ($pick_code) = $url=~m{\/([^/]+)$};
 my $api_url = "http://u.115.com/?ct=upload_api&ac=get_pick_code_info&pickcode=$pick_code&version=3";
 my $content=get($api_url);

 my ($urls, $file_name) = $content=~/"DownloadUrl":(.*?)"FileName":"(.*?)",/s;
 $file_name=conv_filename($file_name);

 my @down_urls = $urls=~/"Url":"(.*?)"/sg;
 s#\\\/#/#g for @down_urls;

 for my $u (@down_urls){
  my $wget_cmd=qq{wget -c "$u" -O "$file_name"};
  print $wget_cmd,"\n\n";
  `$wget_cmd`;
 }

 return ($file_name, \@down_url);
}

sub conv_filename {
 my ($file_name) = @_;
 my @file_keys = split /(\\u.{4})/, $file_name;
 for(@file_keys){
  my ($x) = /\\u(.{4})/;
  next unless($x);
  my $cmd = 'encode("cp936","\x{'.$x.'}")';
  $_= eval $cmd;
 }
 $file_name=join "", @file_keys;
 return $file_name;
}
