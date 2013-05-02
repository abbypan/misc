#===============================================================================
#  DESCRIPTION:  豆豆小说阅读网
#       AUTHOR:  AbbyPan (USTC), <abbypan@gmail.com>
#===============================================================================
package Novel::Parser::Dddbbb;
use strict;
use warnings;
use utf8;
use Moo;
extends 'Novel::Parser::Base';
use HTML::TableExtract qw/tree/;
use Web::Scraper;
use Encode;

has '+domain'  => ( default => sub {'http://www.dddbbb.net'} );
has '+site'    => ( default => sub {'Ddvip'} );
has '+charset' => ( default => sub {'cp936'} );

sub generate_chapter_url {
    my ( $self, $book_id, $chapter_id, $id ) = @_;
    return ( $book_id, $chapter_id ) if ( $book_id =~ /^http/ );
    my $url = "$self->{domain}/${book_id}_$chapter_id.html";
    return ( $url, $id );
} ## end sub generate_chapter_url

sub alter_chapter_before_parse {
    my ( $self, $html_ref ) = @_;
    for ($$html_ref) {
        s#\<img[^>]+dou\.gif[^>]+\>#，#g;
    }
} ## end sub alter_chapter_before_parse

sub parse_chapter {

    my ( $self, $html_ref ) = @_;

    my $parse_chapter = scraper {
        process_first '#toplink', 'book_info' => sub {
            my ( $writer, $book ) =
                map { $_->as_trimmed_text } ( $_[0]->look_down( '_tag', 'a' ) )[ 3, 4 ];
            return [ $book, $writer ];
        };
        process_first '.mytitle', 'chapter' => sub { $_[0]->as_trimmed_text };
        process_first '#content', 'content' => sub { $self->get_elem_html( $_[0] ) };
        result 'book_info', 'chapter', 'content';

    };
    my $ref = $parse_chapter->scrape($html_ref);

    @{$ref}{ 'book', 'writer' } = @{ $ref->{book_info} };

    return $ref;
} ## end sub parse_chapter

sub generate_index_url {

    my ( $self, $id_1, $id_2 ) = @_;
    return $id_1 if ( $id_1 =~ /^http/ );
    return "$self->{domain}/$id_1/$id_2/index.html";
} ## end sub generate_index_url

sub parse_index {

    my ( $self, $html_ref ) = @_;
    my $parse_index = scraper {
        process_first '.cntPath', 'book_info' => sub {
            my ( $writer, $book ) = ( $_[0]->look_down( '_tag', 'a' ) )[ 3, 4 ];
            return [
                $writer->as_trimmed_text, $writer->attr('href'),
                $book->as_trimmed_text,   $book->attr('href')
            ];
        };
        process_first '.bookintro', 'intro' => sub { $self->get_elem_html( $_[0] ) };
        process_first '.bookimage', 'book_img' => sub {
            my $url = $_[0]->look_down( '_tag', 'img' )->attr('src');
            return if ( $url =~ /default.gif/ );
            return $self->{domain} . $url;
        };
        result 'book_info', 'intro', 'book_img';

    };

    my $parse_index_other = scraper {
        process_first '#lc', 'book_info' => sub {
            my ( $writer, $book ) = ( $_[0]->look_down( '_tag', 'a' ) )[ 2, 3 ];
            return [
                $writer->as_trimmed_text, $self->{domain} . $writer->attr('href'),
                $book->as_trimmed_text,   $self->{domain} . $book->attr('href')
            ];
        };
        process_first '//table[@width="95%"]//td[2]', 'intro' => sub {
            $_[0]->look_down( '_tag', 'script' )->delete;
            $self->get_elem_html( $_[0] );
        };
        process_first '//td[@width="120"]', 'book_img' => sub {
            my $url = $_[0]->look_down( '_tag', 'img' )->attr('src');
            return if ( $url =~ /default.gif/ );
            return $self->{domain} . $url;
        };
        result 'book_info', 'intro', 'book_img';
    };

    my $ref =
          $$html_ref =~ /<h2 id="lc">/
        ? $parse_index_other->scrape($html_ref)
        : $parse_index->scrape($html_ref);
    @{$ref}{ 'writer', 'writer_url', 'book', 'book_url' } = @{ $ref->{book_info} };
    ( my $book_info_url = $ref->{book_url} ) =~ s#index.html$#opf.html#;
    $ref->{book_info_urls}{$book_info_url} = sub { $self->parse_chapter_info(@_) };

    return $ref;
} ## end sub parse_index

sub parse_chapter_info {

    #章节信息
    my ( $self, $ref, $html_ref ) = @_;

    my $refine_engine = scraper {
        process_first '.opf', 'chapter_urls' => sub {
            my @urls = $_[0]->look_down( '_tag', 'a' );
            unshift @urls, undef;
            for my $i ( 1 .. $#urls ) {

                $ref->{chapter_urls}->[$i] = $self->{domain} . $urls[$i]->attr('href');
                push @{ $ref->{chapter_info} },
                    { 'id' => $i, 'title' => $urls[$i]->as_trimmed_text, };
            } ## end for my $i ( 1 .. $#urls)
            return \@urls;
        };
        result 'chapter_urls';
    };

    $refine_engine->scrape($html_ref);
    $ref->{chapter_num} = $#{ $ref->{chapter_urls} };
    return;
} ## end sub parse_chapter_info

sub generate_writer_url {

    my ( $self, $writer_id ) = @_;
    return $writer_id if ( $writer_id =~ /^http/ );
    return "$self->{domain}/html/author/$writer_id.html";
} ## end sub generate_writer_url

sub parse_writer {

    my ( $self, $html_ref ) = @_;

    my $parse_writer = scraper {
        process_first '#list',
            writer => sub { ( $_[0]->look_down( '_tag', 'font' ) )[0]->as_trimmed_text };
        process_first '#border_1', series => sub {
            my @books = $_[0]->look_down( '_tag', 'ul' );
            shift(@books);
            my @urls;
            for my $book (@books) {
                my $url = $book->look_down( 'id', 'idname' )->look_down( '_tag', 'a' );
                next unless ( defined $url );

                my $series = $book->look_down( 'id', 'idzj' )->as_text;
                $series =~ s/\s*(\S*)\s*.*$/$1/;

                my $bookname = $url->as_trimmed_text;
                push @urls, [ $series, $bookname, $self->{domain} . $url->attr('href') ];
            } ## end for my $book (@books)
            return \@urls;
        };
        result 'writer', 'series';
    };

    my $ref = $parse_writer->scrape($html_ref);

    return $ref;
} ## end sub parse_writer

sub make_query_url {

    my ( $self, $type, $keyword ) = @_;

    my $url = $self->{domain} . '/search.php';

    my %Query_Type = ( '作品' => 'name', '作者' => 'author', '主角' => 'main', );

    return (
        $url,
        {   'keyword' => $keyword,
            'select'  => $Query_Type{$type},
            'Submit'  => encode( $self->{charset}, '搜索' ),
        },
    );

} ## end sub make_query_url

sub parse_query {

    my ( $self, $html_ref ) = @_;
    my $parse_query = scraper {
        process '//h3', 'books[]' => sub {
            my $bookname = $_[0]->look_down( '_tag', 'a' );
            return unless ( defined $bookname );
            my ($bname) = $bookname->as_trimmed_text;
            my $writer = $_[0]->right->look_down( '_tag', 'a' )->as_trimmed_text;
            return [ $writer, $bname, $self->{domain} . $bookname->attr('href') ];
        };
        result 'books';
    };
    my $ref = $parse_query->scrape($html_ref);

    return $ref;
} ## end sub parse_query

1;
