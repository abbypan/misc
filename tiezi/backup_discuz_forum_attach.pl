#!/usr/bin/perl 
#===============================================================================
#  DESCRIPTION: 有mysql帐号，无ftp帐号，备份 discuz x2 论坛附件
#       AUTHOR: Abby Pan (USTC), abbypan@gmail.com
#      CREATED: 2012年07月01日 11时25分08秒
#===============================================================================

use strict;
use warnings;

### config 
use LoadThread::SiteConfig;
my $mysql = $LoadThread::SiteConfig::MYSQL;
my $site     = $LoadThread::SiteConfig::SITE;

my ($dest_dir) = @ARGV;

my $web_dir   = "$site/data/attachment/forum";
my $local_dir = "$dest_dir/data/attachment/forum";
`mkdir -p $local_dir` unless ( -d $local_dir );

print "get attach tables\n";
my $table_prefix  = 'pre_forum_attachment_';
my $attach_sql    = qq[$mysql -e "show tables like '$table_prefix%'"];
my $attach_table  = `$attach_sql`;
my @attach_tables = grep {/_\d+$/} ( split /\n/, $attach_table );

print "deal attach list\n";
for my $t (@attach_tables) {
    print "get attach $t\n";
    my $attach = `$mysql -e "select attachment from $t"`;
    my @attach_files = split /\n/, $attach;
    
    print "check attach files\n";
    for my $f (@attach_files) {
        print "check $f\n";
        my $loc_f = "$local_dir/$f";
        next if ( -f $loc_f );

        my ($dir) = $loc_f =~ /(.+)\//;
        `mkdir -p $dir` unless ( -d $dir );

        my $web_f = "$web_dir/$f";
        system("/usr/bin/curl $web_f -o $loc_f -s --compressed");
        print "finish download $f\n";
    }
}
