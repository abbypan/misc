#!/usr/bin/perl 
#===============================================================================
#  DESCRIPTION: 单本书的坑品
#       AUTHOR: Abby Pan (USTC), abbypan@gmail.com
#      CREATED: 2012年08月05日 16时46分34秒
#===============================================================================
#章节更新的时间间隔 X 天
# 全文字数/章节数/(最后init更新 - 最早init更新)

use strict;
use warnings;

use utf8;

binmode( STDIN,  ":encoding(utf8)" );
binmode( STDOUT, ":encoding(utf8)" );
binmode( STDERR, ":encoding(utf8)" );

use Data::Dump qw/dump/;
use Encode;
use MongoDB;
use DateTime;
use DateTime::Format::HTTP;

our $HOST       = 'localhost';
our $PORT       = 27017;
our $CONNECTION = MongoDB::Connection->new( host => $HOST, port => $PORT );
our $DB         = $CONNECTION->jjwxc;
our $COLL       = $DB->book;

my ($book_id) = @ARGV;
$book_id = int($book_id);

calc_keng_pin($book_id);


sub calc_keng_pin {
    my ($book_id) = @_;


    my $book_info = $COLL->find_one( { _id => $book_id } );

    my $is_keng = 0;
    my $keng_rank = '未知';

    my $last_update_days = calc_last_update_interval($book_info);
    $is_keng = 1 if($last_update_days>90);

    my $interval_days = get_chapter_write_interval($book_info);
    my $main_write_days = get_main_write_days($book_info);

}

sub check_update_type {
    my ($intervals) = @_;
	if( intervals<0 ) return '错误';
	if( intervals<4 ) return '日更';
	if( intervals<8 ) return '周更';
	if( intervals<16 ) return '半月更';
	if( intervals<32 ) return '月更';
	if( intervals<94 ) return '季更';
	if( intervals<184 ) return '半年更';
	if( intervals<366 ) return '年更';
	if( intervals<732 ) return '太阳黑子活动周期更';
	return '冰川周期更';
}

sub get_chapter_write_interval {
# 章节更新时间间隔
    my ($book_info) = @_;

    my @init_times =
        map { DateTime::Format::HTTP->parse_datetime($_) }
        map { $_->{init_time} } @{ $book_info->{chapter_info} };

    my @result;
    for my $i (1.. $#init_times){
        my ($b, $n) = @init_times[$i-1 , $i]; 
        my $dur = $n->delta_days($b);
        push @result, $dur->{days};
    }
    
    return \@result;
}

sub get_main_write_days {

    # 最后章节启动时间　- 最先章节启动时间
    my ($book_info) = @_;

    my @init_times =
        map { DateTime::Format::HTTP->parse_datetime($_) }
        sort
        map { $_->{init_time} } @{ $book_info->{chapter_info} };

    my ( $first, $last ) = @init_times[ 0, -1 ];
    my $dur = $last->delta_days($first);
    return $dur->{days};
}

sub calc_last_update_interval {

    #最近一次更新距今 X 天(如果已完成，则 X = 0 )

    my ($book) = @_;

    #已完结/已出版
    return 0 if ( $book->{process} == 0 or $book->{is_in_print} == 1 );

    my $last_update = get_last_update($book);
    my $now         = DateTime->now();
    my $dur         = $now->delta_days($last_update);

    return $dur->{days};
}

sub get_last_update {

    #最近一次更新时间
    my ($book) = @_;

    my @update_times =
        map { DateTime::Format::HTTP->parse_datetime($_) }
        sort
        map { $_->{update_time} } @{ $book->{chapter_info} };

    return $update_times[-1];
}
