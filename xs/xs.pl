#!/usr/bin/perl 
#===============================================================================
#  DESCRIPTION:  小说下载程序
#       AUTHOR:  AbbyPan (USTC), <abbypan@gmail.com>
#===============================================================================
use strict;
use warnings;
use utf8;

use Encode;
use File::Path qw/mkpath/;
use File::Find::Rule;
use Getopt::Long;

use FindBin;
use lib "$FindBin::RealBin/lib";
use Novel::Agent;

$| = 1;

use vars qw($SITE %AGENT %BROWSER %TEMPLATE $PACKER_TYPE %PACKER $help $in $action $dir $arg);
GetOptions(

    #站点
    'site|s=s' => \$SITE,

    #要处理的对象
    'in|i=s' => \$in,

    #下载目录
    'dir|d=s' => \$dir,

    #重试次数
    'retry=i' => \$BROWSER{retry},

    #并行下载线程数
    'parallel=i' => \$AGENT{parallel},

    #覆盖
    'overwrite' => \$PACKER{overwrite},

    #跳过
    'skip' => \$PACKER{skip},

    #命名格式
    'name=s' => \$PACKER{book_name_format},

    'packertype=s' => \$PACKER_TYPE,

    #递归
    'no-recur' => sub { $AGENT{recur} = 0; },    #选单

    #本地编码环境
    'locale|l=s' => \$AGENT{locale},

    #帮助信息
    'help|h' => \$help,

    #指定下载模式为作者
    'writer|w' => sub { $action = 'get_writer'; },

    #检查更新
    'check|c' => sub { $action = 'update_book'; },

    #查询
    'query|q=s' => sub { $arg = $_[1]; $action = 'query'; },

    #文件重命名
    'rename|r=s' => sub { $arg = $_[1]; $action = 'rename_book'; },

    #手动更新
    'fix|f=s' => sub { $arg = [ split( ',', $_[1] ) ]; $action = 'fix_book'; },

);

#默认参数处理
$action ||= 'get_book';    #默认下载小说
$AGENT{recur} //= 0 unless ( $action =~ /(update|rename)_book/ );
$AGENT{parallel}   //= 8;
$PACKER{overwrite} //= 0;
$PACKER{skip}      //= 0;
$PACKER_TYPE ||= 'Zip';
$BROWSER{retry} //= 3;
$SITE ||= 'Jjwxc';
$AGENT{locale} ||= $^O =~ 'Win32' ? 'cp936' : 'utf-8';
$TEMPLATE{template_dir} //= "$FindBin::RealBin/template/$SITE";

#初始化对象
my $xs = Novel::Agent->new(%AGENT);
$xs->set_browser(%BROWSER);
$xs->set_parser($SITE);
$xs->set_template(%TEMPLATE);
$xs->set_packer( $PACKER_TYPE, %PACKER );

#编码
#binmode ( STDIN,  ":encoding($xs->{locale})" );
#binmode ( STDOUT, ":encoding($xs->{locale})" );
#binmode ( STDERR, ":encoding($xs->{locale})" );

#帮助信息
print_usage() if ( $help || !( defined $in ) );

#输入参数的简单处理
if ($dir) { mkpath($dir); chdir($dir); }
if ( $action eq 'query' ) {
    $arg = defined $arg ? decode( $xs->{locale}, $arg ) : '作品';
    $in = decode( $xs->{locale}, $in );
}

#处理函数
my $action_sub = get_action_sub( $xs, $action, $arg );
$action_sub->($_) for split( ',', $in );

sub process_dir {
    my ( $act_sub, $obj, $recur ) = @_;

    #进$obj目录
    my $depth = $recur ? undef : 1;

    my @files = File::Find::Rule->file->name('*.zip')->maxdepth($depth)->in($obj);

    $act_sub->($_) for @files;
} ## end sub process_dir

sub get_action_sub {
    my ( $xs, $action, $arg ) = @_;
    my %action_sub = (
        'get_book' => sub {
            $xs->get_book( split( '-', $_[0] ) );
        },
        'get_writer' => sub {
            $xs->get_writer( split( '-', $_[0] ) );
        },
        'fix_book' => sub {
            $xs->update_book( $_[0], $arg );
        },
        'query' => sub {
            $xs->query( $arg, $_[0] );
        },
        'update_book' => sub {
            process_dir( sub { $xs->update_book( $_[0] ); }, $_[0], $xs->{recur} );
        },
        'rename_book' => sub {
            process_dir( sub { $xs->rename_book( $_[0], $arg ); }, $_[0], $xs->{recur} );
        },
    );

    return $action_sub{$action};
} ## end sub get_action_sub

sub print_usage {
    my $usage = <<'__USAGE__';
参数:
-s  --site      指定小说站点（默认是绿晋江）
   绿晋江：Jjwxc | 豆豆: Dddbbb

-i  --in        指定小说号、作者号、待处理的目录、待解析的网址等
-d  --dir       指定小说下载后存放的目录
-w  --writer    指定按作者号下载（默认是按小说号下载）

-c  --check     检查某小说是否有更新（默认动作是下载）
-q  --query     指定查询的类型，根据关键字进行查询（默认是按作品查询）
    绿晋江：作品/作者/其他/主角/配角
    豆豆：作品/作者/主角

-h  --help      更多帮助信息
__USAGE__

    $usage .= <<'__MORE__' if ($help);

更多参数:
-r  --rename    指定文件重命名方式（作者：{w}，书名：{b}）
-f  --fix       指定手动更新的章节

--no-recur      下载时不按系列建目录 或者 检查更新、文件重命名时目录不递归
--no-select     不出现选单，全部下载
--overwrite     下载时覆盖同名文件
--skip          下载时如果存在同名文件就跳过
--name          指定文件下载时的命名方式({w}作者，{b}书名，{s}系列)
--retry         指定重连次数(默认是3)
--parallel      指定并行下载线程数(默认是8)

例子：
下载绿晋江上的 <何以笙箫默> ：xs -i 2456
下载绿晋江上的 <顾漫> 专栏：xs -w -i 3243
查询绿晋江作品名为 <何以笙箫默> 的小说：xs -q 作品 -i 何以笙箫默
更新 <顾漫> 目录下的小说：xs -c -i 顾漫
手动更新 <何以笙箫默.zip> 小说的第 3,5 两章：xs -f 3,5 -i 何以笙箫默.zip
以'作者名-小说名'的格式重命名 <顾漫> 目录下的小说：xs -r '{w}-{b}' -i 顾漫
__MORE__
    print encode( $xs->{locale}, $usage );
    exit;
} ## end sub print_usage
