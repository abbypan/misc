#!/usr/bin/perl 
#===============================================================================
#        USAGE: ./load_tiezi_into_discuz.pl [fid] [file or dir]
#  DESCRIPTION: 将保存的帖子内容导入discuz的数据库(目前支持x2)
#       AUTHOR: Abby Pan (USTC), abbypan@gmail.com
#      CREATED: 2012/3/12 00:48:48
#===============================================================================

use strict;
use warnings;

use LoadThread::DiscuzX2;
use LoadThread::SiteConfig;

my ( $fid, $obj ) = @ARGV;

unless ( $fid and ( -f $obj or -d $obj ) ) {
    print "please input : ./$0 [fid] [file or dir]";
    exit;
}

our $DBH = LoadThread::DiscuzX2->new(
    connect_info => [
        $LoadThread::SiteConfig::DSN, $LoadThread::SiteConfig::USERNAME,
        $LoadThread::SiteConfig::PASSWORD
    ]
);

$DBH->do("SET character_set_client='$LoadThread::SiteConfig::CHARSET'");
$DBH->do("SET character_set_connection='$LoadThread::SiteConfig::CHARSET'");
$DBH->do("SET character_set_results='$LoadThread::SiteConfig::CHARSET'");

my @files = -f $obj ? ($obj) : glob("$obj/*");
$DBH->create_thread( $fid, $_ ) for @files;
