#!/usr/bin/perl 
#===============================================================================
#         FILE:  get_115file.pl
#        USAGE:  ./get_115file.pl 查看使用说明
#  DESCRIPTION:  下载115网盘的文件
#       AUTHOR:  AbbyPan (USTC), <abbypan@gmail.com>
#      VERSION:  1.2
#      CREATED:  2010/9/24 4:22:14 中国标准时间
#===============================================================================
use strict;
use warnings;

use LWP::Simple;
use Encode;
use utf8;
$| = 1;

#binmode ( STDIN,  ":encoding(cp936)" );
#binmode ( STDOUT, ":encoding(cp936)" );
#binmode ( STDERR, ":encoding(cp936)" );

my ( $url, $checksum ) = @ARGV;

if ( !$url ) {
    print <<__USAGE__;
正常下载：
./get_115file.pl http://u.115.com/file/f9a95d8eaf

批量正常下载(url.txt中包含多个http地址)：
./get_115file.pl url.txt

获取批量正常下载地址(url.txt中包含多个http地址,url.bat为目标下载指令文件)：
./get_115file.pl url.txt url.bat

优蛋下载(指定checksum)：
./get_115file.pl http://u.115.com/file/f9a95d8eaf A4DFAF8AD4F3C556528512937AF6CBA6
__USAGE__
    exit;
}
elsif ( $url =~ /^http:/ ) {
    my ( $file_name, $down_urls ) =
      $checksum
      ? get_filename_urls_youdan( $url, $checksum )
      : get_filename_urls($url);
    my $cmd = make_download_cmd( $file_name, $down_urls );
    exec_download($cmd);
}
elsif ( -f $url ) {

    open my $fhr, '<', $url;
    my @urls = <$fhr>;
    close $fhr;

    $checksum
      ? make_download_file( \@urls, $checksum )
      : download_multi_file(\@urls);

    #    exec_download($cmd_file);
}

sub make_download_file {
    my ( $urls, $cmd_file ) = @_;
    open my $fhw, '>', $cmd_file;
    for my $url (@$urls) {
        print "get download url : $url";
        my ( $file_name, $down_urls, $sha1 ) = get_filename_urls($url);
        print "filename :  $file_name\n\n";
        my $cmd = make_download_cmd( $file_name, $down_urls );
        print $fhw $cmd, "\n" if ($cmd);
    }
    close $fhw;
}

sub download_multi_file {
    my ($urls) = @_;

    my %cmds = map { $_ => [ undef, undef, undef ] } @$urls;

    while (%cmds) {
        for my $url (@$urls) {
            next unless ( exists $cmds{$url} );
            my ( $file_name, $sha1, $cmd ) = @{ $cmds{$url} };

            print "download : $file_name\n" if ($file_name);
            exec_download($cmd) if ($cmd);

            if ( check_sha1( $file_name, $sha1 ) ) {

                #下载成功
                print "success download : $file_name\n\n";
                delete $cmds{$url};
            }
            else {

                #重新取地址
                print "get download url : $url";
                my ( $file_name, $down_urls, $sha1 ) = get_filename_urls($url);
                print "filename :  $file_name\n\n";
                my $cmd = make_download_cmd( $file_name, $down_urls );
                $cmds{$url} = [ $file_name, $sha1, $cmd ];
            }
            sleep 1;
        }
    }
}

sub check_sha1 {
    my ( $file_name, $sha1 ) = @_;
    return 0 unless ( $file_name and -f $file_name );
    system('cls');
    print "\ncheck_sha1 : $file_name , $sha1\n";
    my ($check_sha1) = `sha1 $file_name` =~ /^(\S+)/;
    return ( $sha1 eq $check_sha1 ) ? 1 : 0;
}

sub exec_download {
    my ($cmd) = @_;
    open my $progress_fh, '-|', $cmd;
    while (<$progress_fh>) {
        system('cls') if (/Download Progress Summary/);
        print;
    }
    close $progress_fh;
}

sub make_download_cmd {
    my ( $file_name, $down_urls ) = @_;
    return unless ( $file_name and @$down_urls );

    my $url_str = join " ", map { qq["$_"] } grep { defined $_ } @$down_urls;
    return unless ($url_str);
    my $aria2c_cmd =
qq{aria2c -c --summary-interval=2 --log-level=info --use-head=false -o "$file_name" $url_str};

    return $aria2c_cmd;
}

sub get_filename_urls {
    my ($url) = @_;
    my $content = encode( 'cp936', get($url) );
    my ($file_name) = $content =~ m{<h2.*?>(.*)?</h2>}s;
    return unless ($file_name);
    my @down_urls = $content =~ m{<a class="normal-down" href="(http.*?)" }sg;
    my ($sha1) = $content =~ m[SHA1..(.+?)\&nbsp\;]s;
#    @down_urls[ 0, 1 ] = @down_urls[ 1, 0 ];
    return ( $file_name, \@down_urls, lc($sha1) );
}

sub get_filename_urls_youdan {
    my ( $url, $checksum ) = @_;

    my ($pick_code) = $url =~ m{\/([^/]+)$};

    my $api_url =
"http://u.115.com/?ct=upload_api&ac=get_pick_code_info&pickcode=$pick_code&checksum=$checksum&version=1160";
    my $content =
`wget $api_url --header="User-Agent: Mozilla/4.0 (compatible; MSIE 6.0; Windows NT 5.3)" -q -O -`;

    my ( $urls, $file_name ) =
      $content =~ /"DownloadUrl":(.*?)"FileName":"(.*?)",/s;
    $file_name = conv_filename($file_name);

    my @down_urls = $urls =~ /"Url":"(.*?)"/sg;
    s#\\\/#/#g for @down_urls;
#    @down_urls[ 0, 1 ] = @down_urls[ 1, 0 ];

    return ( $file_name, \@down_urls );

}

sub conv_filename {
    my ($file_name) = @_;
    my @file_keys = split /(\\u.{4})/, $file_name;
    for (@file_keys) {
        my ($x) = /\\u(.{4})/;
        next unless ($x);
        my $cmd = 'encode("cp936","\x{' . $x . '}")';
        $_ = eval $cmd;
    }
    $file_name = join "", @file_keys;
    return $file_name;
}
