#!/usr/bin/perl 
#===============================================================================
#  DESCRIPTION: 绿晋江小说信息，以JSON输出
#       Author: Abby Pan (USTC), abbypan@gmail.com
#      CREATED: 2012年12月26日 星期三 23时22分40秒
#===============================================================================
use strict;
use warnings;

use Encode qw/from_to/;
use JSON;
$| = 1;

my ($book_id) = @ARGV;

my $r = deal_one_book($book_id);
print to_json($r), "\n" if($r);

sub deal_one_book {
    my ($book_id) = @_;
    return unless ($book_id);

    my $res = get_book_info($book_id);
    return if ( is_empty_book($res) );

    my %info;
    $info{id}   = $book_id;
    $info{name} = extract_book_name($res);
    return unless ( $info{name} );

    @info{qw/author_id author_name/} = extract_author_info($res);

    my $book_info = extract_book_info($res);
    $info{$_} = $book_info->{$_} for keys(%$book_info);

    my $chap_info = extract_chapter_info($res);
    $info{$_} = $chap_info->{$_} for keys(%$chap_info);

    return \%info;
} ## end sub deal_one_book

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

sub extract_book_name {
    my ($res_ref) = @_;

    my ($book_name) = $$res_ref =~ m{<h1>(.+?)</h1>}s;
    return unless ($book_name);

    $book_name =~ s[^.*<span class="bigtext">\s*][]s;
    $book_name =~ s[\s*</span>.*$][]s;
    $book_name =~ s[<br/>][ ]sg;
    $book_name =~ s/&nbsp;/ /sg;
    $book_name =~ s/[ ]+/ /sg;
    return unless ( $book_name =~ /\S/ );
    return $book_name;
} ## end sub extract_book_name

sub is_empty_book {
    my ($res_ref) = @_;
    return 1 if ( $$res_ref =~ /被锁文章/s );
    return 1 if ( $$res_ref =~ /<title>《》/s );
    return 0;
} ## end sub is_empty_book

sub get_book_info {
    my ($book_id) = @_;
    my $res = `curl http://www.jjwxc.net/onebook.php?novelid=$book_id -s --compressed`;
    from_to( $res, 'cp936', 'utf8' );
    return \$res;
} ## end sub get_book_info

sub extract_author_info {
    my ($r) = @_;
    my ( $a_id, $a_name ) = $$r =~ m{<h2>作者：<a href=.*?authorid=(\d+)>(.+?)</a></h2>}s;
    ( $a_id, $a_name ) = $$r =~ m{</h1>作者：<a href=.*?authorid=(\d+)>(.+?)</a>}s
        unless ($a_id);
    return ( $a_id, $a_name );
} ## end sub extract_author_info

sub extract_book_info {
    my ($res) = @_;
    my %info;
    my ($book_info) = $$res =~ m{文章基本信息</div></div>(.+?)</div>}s;
    ( $info{type} ) = $book_info =~ m{文章类型.*?</span>\s*(\S+?)\s*</li>}s;
    $info{type} = [ split /-/, $info{type} ] if ( $info{type} );

    ( $info{style} )  = $book_info =~ m{作品风格.*?</span>\s*(\S+?)\s*</li>}s;
    ( $info{series} ) = $book_info =~ m{所属系列.*?</span>\s*(\S+?)\s*</li>}s;
    $info{series} =~ s#<br/># #sg;
    $info{series} =~ s#&nbsp;# #sg;
    ( $info{process} ) = $book_info =~ m{文章进度.*?</span>\s*(\S+?)\s*</li>}s;
    $info{process} = map_process( $info{process} );
    ( $info{word_num} ) = $book_info =~ m{全文字数.*?</span>\s*(\S+?)字\s*</li>}s;
    $info{word_num} = map_string_number( $info{word_num} );
    ( $info{is_print} ) = $book_info =~ m{是否出版.*?</span>\s*(\S+?)\s*</li>}s;
    $info{is_print} = $info{is_print} =~ /已出版/ ? 1 : 0;

    ( $info{tag} ) = $$res =~ m{内容标签：\s*(.+?)\s*</font><br/><br/>}s;
    $info{tag} = map_string_list( $info{tag} );
    my ($content_info) = $$res =~ m{搜索关键字：\s*(.*?)\s*</span></div>}s;
    my @content_infos = split /\s*┃\s*/, $content_info;
    @info{qw/leading_role supporting_role keyword/} =
        map {
        s/.*?：\s*//;
        /^无$/ ? [] : map_string_list($_);
        } @content_infos;
    return \%info;
} ## end sub extract_book_info

sub map_string_list {
    my ($s) = @_;
    return [] unless ($s);
    $s =~ s/、|，/ /gs;
    return [ split /\s+/, $s ];
} ## end sub map_string_list

sub extract_cell_chapter {
    my ($r) = @_;

    my @cell = split /<\/td>/, $r;

    my %cell;
    ( $cell{id} )   = $cell[0] =~ m{<div align="center">(\d+)</div>}s;
    ( $cell{name} ) = $cell[1] =~ m{chapterid=\d+">\s*(.+?)\s*</a>}s;

    if ( $cell{name} ) {
        $cell{is_lock} = 0;
    }
    elsif ( $cell[1] =~ m#\[锁\]</span>\s+</div>#s ) {
        $cell{name}    = '锁';
        $cell{is_lock} = 1;
    }
    return unless ( $cell{name} );

    ( $cell{word_num} ) = $cell[3] =~ m{>(.+)}s;
    $cell{word_num} = map_string_number( $cell{word_num} );

    ( $cell{click_count} ) = $cell[4] =~ m{>(.+)}s;
    $cell{click_count} = map_string_number( $cell{click_count} );

    ( $cell{update_time} ) = $cell[5] =~ m{">(.+)}s;
    $cell{update_time} =~ s/<.*//;
    return \%cell;
} ## end sub extract_cell_chapter

sub extract_chapter_info {
    my ($res) = @_;
    my %info;

    my ($chap_info) = $$res =~ m{<td width="216">更新时间</td>.*?(<tr>.+?</tbody>)}s;
    if ($chap_info) {
        my @chapters = $chap_info =~ m{<tr>(.*?)</tr>}sg;
        for my $r (@chapters) {
            my $c = extract_cell_chapter($r);
            next unless ($c);
            push @{ $info{chapter_info} }, $c;
        }
        ( my $last_info = $chapters[-1] ) =~ s/\s*<.*?>\s*//gs;

        @info{qw/download_count click_count comment_count collect_count rank/} =
            map { map_string_number($_) }
            grep {/\d/} ( split /：/, $last_info );
    } ## end if ($chap_info)
    else {
        @info{qw/click_count comment_count collect_count rank/} = $$res
            =~ m{总点击数：.*?([\d,]+).*?：.*?([\d,]+).*?：.*?([\d,]+).*?：.*?([\d,]+)}s;
        @info{qw/update_time rank/} =
            $$res =~ m{最新更新:([\d\- :]+)? 作品积分：([\d,]+)" />}s;
        my %cell;
        $cell{id} = 1;
        ( $cell{name} ) = $$res =~ m{<h2>(.+?)</h2>}s;
        $cell{word_num}    = $info{word_num};
        $cell{click_count} = $info{click_count};
        $cell{update_time} = $info{update_time};
        push @{ $info{chapter_info} }, \%cell;
    } ## end else [ if ($chap_info) ]

    $info{chapter_num} = scalar( @{ $info{chapter_info} } );
    $info{rank_per_chapter} = $info{chapter_num} ? int( $info{rank} / $info{chapter_num} ) : 0;

    return \%info;
} ## end sub extract_chapter_info
