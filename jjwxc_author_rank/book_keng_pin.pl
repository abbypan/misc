#!/usr/bin/perl 
#===============================================================================
#  DESCRIPTION: ������Ŀ�Ʒ
#       AUTHOR: Abby Pan (USTC), abbypan@gmail.com
#      CREATED: 2012��08��05�� 16ʱ46��34��
#===============================================================================
#�½ڸ��µ�ʱ���� X ��
# ȫ������/�½���/(���init���� - ����init����)

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
    my $keng_rank = 'δ֪';

    my $last_update_days = calc_last_update_interval($book_info);
    $is_keng = 1 if($last_update_days>90);

    my $interval_days = get_chapter_write_interval($book_info);
    my $main_write_days = get_main_write_days($book_info);

}

sub check_update_type {
    my ($intervals) = @_;
	if( intervals<0 ) return '����';
	if( intervals<4 ) return '�ո�';
	if( intervals<8 ) return '�ܸ�';
	if( intervals<16 ) return '���¸�';
	if( intervals<32 ) return '�¸�';
	if( intervals<94 ) return '����';
	if( intervals<184 ) return '�����';
	if( intervals<366 ) return '���';
	if( intervals<732 ) return '̫�����ӻ���ڸ�';
	return '�������ڸ�';
}

sub get_chapter_write_interval {
# �½ڸ���ʱ����
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

    # ����½�����ʱ�䡡- �����½�����ʱ��
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

    #���һ�θ��¾�� X ��(�������ɣ��� X = 0 )

    my ($book) = @_;

    #�����/�ѳ���
    return 0 if ( $book->{process} == 0 or $book->{is_in_print} == 1 );

    my $last_update = get_last_update($book);
    my $now         = DateTime->now();
    my $dur         = $now->delta_days($last_update);

    return $dur->{days};
}

sub get_last_update {

    #���һ�θ���ʱ��
    my ($book) = @_;

    my @update_times =
        map { DateTime::Format::HTTP->parse_datetime($_) }
        sort
        map { $_->{update_time} } @{ $book->{chapter_info} };

    return $update_times[-1];
}
