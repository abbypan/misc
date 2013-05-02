#!/usr/bin/perl 
#===============================================================================
#  DESCRIPTION: 作者专栏信息，以JSON格式输出
#       AUTHOR: Abby Pan (USTC), abbypan@gmail.com
#      CREATED: 2012年12月27日 星期四 00时28分30秒
#===============================================================================

use strict;
use warnings;

use Encode qw/from_to/;
use JSON;

$| = 1;

my ($author_id) = @ARGV;
my $r = extract_author($author_id);
print to_json($r), "\n" if ($r);

sub extract_author_name {
    my ($r) = @_;
    my ($author_name) = $$r =~ /<span id="favorite_author" rel="(.+?)"/s;
    return $author_name;
}

sub get_author_info {
    my ($author_id) = @_;
    my $res = `curl http://www.jjwxc.net/oneauthor.php?authorid=$author_id -s --compressed`;
    from_to( $res, 'cp936', 'utf8' );
    return \$res;
} ## end sub get_author_info

sub extract_author_link {
    my ($r) = @_;

    my ($table) = $$r =~ m{友情链接(.+?)</table>}s;
    return [] unless ($table);

    my %author_link =
        $table =~ m#<a href=/oneauthor\.php\?authorid=(\d+) target=_blank>(.+?)</a>#sg;
    return \%author_link;
} ## end sub extract_author_link

sub extract_last_update_book_info {
    my ($r) = @_;

    my ($last) = $$r =~ m[最近更新作品：(.+?)</tbody>]s;
    return unless ($last);

    my %info;
    @info{qw/id name process word_num last_update_time/} =
        $last
        =~ m[novelid=(\d+)">《(.+?)》.+?作品状态：<font color=black>(.+?)</font>.+?作品字数：<font color=black>(.+?)</font>.+?最后更新时间：.+?</font>\s+(.+?\S)\s+</td>]s;
    $info{process}  = map_process( $info{process} );
    $info{word_num} = map_string_number( $info{word_num} );
    return \%info;
} ## end sub extract_last_update_book_info

sub map_process {
    my ($process) = @_;
    $process =
          $process =~ /已完成/ ? 0
        : $process =~ /连载中/ ? 1
        :                           -1;
    return $process;
} ## end sub map_process

sub map_string_number {
    my ($s) = @_;
    $s =~ s/\D//g;
    return int($s);
}

sub extract_author {
    my ($author_id) = @_;
    return unless($author_id);

    my $res = get_author_info($author_id);

    my %info;
    $info{id} = $author_id;

    $info{name} = extract_author_name($res);
    return unless ( $info{name} );

    $info{author_link}           = extract_author_link($res);
    $info{last_update_book_info} = extract_last_update_book_info($res);

    $info{book_list} = extract_book_list($res);
    $info{book_num}  = scalar( @{ $info{book_list} } );

    return \%info;
} ## end sub extract_author

sub extract_book_list {
    my ($r)         = @_;
    my ($book_list) = $$r
        =~ m[<td width="377" height="18" align="center" bgcolor="#9FD59E">作品</td>(.+?)<table width="984"]s;
    my @book_list;
    my @trs = $book_list =~ m#<tr>(.+?首次存稿时间.+?)</tr>#sg;
    for my $tr (@trs) {
        my %temp;
        @temp{qw/id name/} = $tr =~ m#novelid=(\d+)\s*>\s*&nbsp;(.+?)\s*</a>#s;
        $temp{is_print} = $tr =~ m#<img src=/images/published.gif alt=已出版># ? 1 : 0;
        @temp{qw/type style process word_num rank init_time/} =
            map { s/&nbsp;//; $_ } ( $tr =~ m#<td[^>]+>\s*(.+?)\s*</td>#sg );
        $temp{$_} = map_string_number( $temp{$_} ) for (qw/word_num rank/);
        $temp{process} = map_process( $temp{process} );
        $temp{type} = [ split '-', $temp{type} ];
        push @book_list, \%temp;
    } ## end for my $tr (@trs)
    return \@book_list;
} ## end sub extract_book_list
