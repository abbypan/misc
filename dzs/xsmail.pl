#!/usr/bin/perl
#===============================================================================
#  DESCRIPTION:  将html小说发送到指定邮箱
#  AUTHOR:  Abby Pan (USTC), abbypan@gmail.com
#  CREATED:  2011年10月09日 21时52分13秒
#===============================================================================

use strict;
use warnings;
use utf8;

use Encode;
use File::Slurp qw/slurp/;
use POSIX qw/strftime/;

use Getopt::Long;
use Config::Simple;
use Authen::SASL;
use MIME::Lite;
use Net::SMTP;
use Net::SMTP::SSL;
use FindBin;
use lib "$FindBin::RealBin/lib";

#use Smart::Comments '###';

$| = 1;

my ( $mail, $file, $help, $locale );

GetOptions(
    'mail|m=s'   => \$mail,
    'file|f=s'   => \$file,
    'locale|l=s' => \$locale,
    'help|h'     => \$help,
);

$locale //= $^O eq 'MSWin32' ? 'cp936' : 'utf-8';
binmode( STDIN,  ":encoding($locale)" );
binmode( STDOUT, ":encoding($locale)" );
binmode( STDERR, ":encoding($locale)" );

print_usage() if ( $help or ( !$file or !-f $file ) );

$mail ||= "$FindBin::RealBin/xsmail.conf";
my $mail_conf = read_mail_config($mail);

my $init_time = strftime "%Y-%m-%d %H:%M:%S", localtime;
print "[$init_time] 初始化读入 ", decode( $locale, $file ), "\n";
my $novel_info = read_novel_info($file);
my $title      = "小说 : $novel_info->{title}";

my $begin_time = strftime "%Y-%m-%d %H:%M:%S", localtime;
print "[$begin_time] 开始邮件发送 $title\n";
send_mail( $mail_conf, $title, $novel_info->{content}, undef );
my $end_time = strftime "%Y-%m-%d %H:%M:%S", localtime;
print "[$end_time] 结束邮件发送 $title\n";

sub read_mail_config {
    my ($mail) = @_;
    unless ( -f $mail ) {
        print "请指定xsmail.conf！\n";
        exit;
    }

    my %mail_conf;
    Config::Simple->import_from( $mail, \%mail_conf );

    return \%mail_conf;
}

sub read_novel_info {
    my ($file) = @_;

    my $html = decode( 'utf8', slurp($file) );

    my %info;
    $info{content} = \$html;

    ( $info{writer} ) = $html =~ m#id="writer">(.*?)<#s;
    ( $info{book} )   = $html =~ m#id="book">(.*?)<#s;

    ( $info{title} ) = $html =~ m#id="title">(.*?)<#s;
    $info{title} ||= "$info{writer} 《$info{book}》";

    return \%info;
}

sub send_mail {
    my ( $conf, $subject, $html_ref, $attach_files_ref ) = @_;

    my $msg = MIME::Lite->new(
        From    => $conf->{from},
        To      => $conf->{to},
        Subject => $subject,
        Type    => 'multipart/alternative'
    );

    my $body = MIME::Lite->new( Type => 'text/html', Data => $$html_ref, );
    $body->attr( 'content-type.charset' => 'UTF-8' );
    $msg->attach($body);

    for my $f (@$attach_files_ref) {
        $msg->attach(
            Type => $f->{type},
            Id   => $f->{id},
            Path => $f->{path},
        );
    } ## end for my $f (@$attach_files_ref)

    my $smtp = Net::SMTP::SSL->new(
        $conf->{host},
        Hello   => 'abbypan.blogspot.com',
        Port    => $conf->{port},
        Timeout => $conf->{timeout},

        #Debug   => 1,
    ) or die "new error\n";
    $smtp->auth( @{$conf}{ 'usr', 'passwd' } )
      || die "auth fail";
    $smtp->mail( $conf->{from} );
    $smtp->to( $conf->{to} );
    $smtp->data();
    $smtp->datasend( $msg->as_string );
    $smtp->dataend();
    $smtp->quit;
} ## end sub send_mail

sub print_usage {
    my $usage = <<'__USAGE__';

例子：发送html小说内容到xsmail.conf中指定的邮箱
	
	xsmail -m xsmail.conf -f 顾漫-何以笙箫默(全文地址见内).html
  
参数：
    -m  --mail      指定邮箱配置文件
    -f  --file      指定要发送的html小说
	-l  --locale    指定本地环境编码，例如cp936/utf-8/...
	-h  --help      指定查看帮助信息
__USAGE__
    print $usage;
    exit;
} ## end sub print_usage

