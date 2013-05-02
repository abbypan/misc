#===============================================================================
#  DESCRIPTION:  把小说内容打包
#       AUTHOR:  AbbyPan (USTC), <abbypan@gmail.com>
#===============================================================================
package  Novel::Packer::Base;
use strict;
use warnings;
use Moo;

use Web::Scraper;
use Encode;
use File::Spec;

has overwrite => (

    #文件同名时是否覆盖
    is      => 'rw',
    default => sub {0},
);

has skip => (

    #文件同名时是否跳过
    is => 'rw',

    default => sub {0},
);

has locale => (

    #本地编码
    is => 'rw',
    #
    default => sub { $^O ne 'MSWin32' ? 'utf-8' : 'cp936' },
);

has book_name_format => (

    #命名格式
    is => 'rw',
    #
    default => sub {'{w}-{b}'},
);

has book_name_suffix => (

    #命名后缀
    is => 'rw',
);

sub pack_update_book {

}

sub pack_book {

}

sub generate_bookname {
    my ( $self, $index_info, $format, $target_dir ) = @_;

    my $bookname = $self->generate_bookname_by_format( $index_info, $format );
    $bookname = "$target_dir/$bookname" if ($target_dir);

    my $check_bookname = $self->check_bookname($bookname);
    return $check_bookname;
} ## end sub generate_bookname

sub check_bookname {
    my ( $self, $file ) = @_;

    #当前文件名可用
    return $file unless ( -f $file );

    #已存在同名文件
    return if ( $self->{skip} );
    return $file if ( $self->{overwrite} );

    #生成新文件名
    while ( -e $file ) {
        if ( $file =~ s/-(\d+)(\.[^.]+)$// ) {
            my $i = $1 + 1;
            $file .= "-$i$2";
        }
        else {
            $file =~ s/\.([^.]+)$/-1.$1/;
        }
    } ## end while ( -e $file )

    return $file;
} ## end sub check_bookname

sub generate_bookname_by_format {

    #根据指定格式生成文件名
    my ( $self, $index_info, $format ) = @_;

    $_ = $format || $self->{book_name_format};

    my %list = ( '{b}' => 'book', '{w}' => 'writer', '{s}' => 'series' );
    while ( my ( $k, $v ) = each %list ) {

        next
            unless ( exists $index_info->{$v}
            and defined $index_info->{$v} );
        $index_info->{$v} =~ s#[ /\,;\*]+##g;

        s/$k/$index_info->{$v}/ if (/$k/);
    } ## end while ( my ( $k, $v ) = each...)

    my $filename = "$_.$self->{book_name_suffix}";
    $filename = encode( $self->{locale}, $filename, Encode::FB_XMLCREF );

    return $filename;
} ## end sub generate_bookname_by_format

sub extract_index_info {
    my ( $self, $html_ref ) = @_;

    my $parse_index = scraper {
        process_first '#site', 'site' => sub { $_[0]->as_trimmed_text };
        process_first '#book',
            'index_url' => sub { $_[0]->attr('href') },
            'book'      => 'TEXT';
        process_first '#writer',      'writer'       => 'TEXT';
        process_first '#series',      'series'       => sub { $_[0]->as_trimmed_text };
        process_first '#chapter_num', 'chapter_num'  => sub { $_[0]->as_trimmed_text };
        process '#chapter_info',      'chapter_info' => sub {
            my @update_time;
            my @chaps_info = $_[0]->look_down( 'class', 'update_time' );
            for my $chap (@chaps_info) {
                my $time = $chap->as_trimmed_text;
                my $type = $chap->attr('type');
                push @update_time, { 'time' => $time, 'type' => $type };
            }
            return \@update_time;
        };
        result 'site', 'index_url', 'book', 'writer', 'series', 'chapter_num', 'chapter_info';
    };
    my $ref = $parse_index->scrape($html_ref);

    return $ref;
} ## end sub extract_index_info

sub extract_chapter_info {

}

sub extract_book_info {

}

no Moo;
1;
