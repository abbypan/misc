#!/usr/bin/perl 
#===============================================================================
#  DESCRIPTION: 将小说自动导入wordpress空间
#       AUTHOR: Abby Pan (USTC), abbypan@gmail.com
#      CREATED: 2012年11月01日 00时08分54秒
#===============================================================================

use strict;
use warnings;

use WordPress::XMLRPC;
use Getopt::Std;
our $WORDPRESS = 'http://xxx.xxx.com/xmlrpc.php';
our $USER      = 'xxx';
our $PASSWD    = 'xxx';

my %opt;
getopt( 'fcti', \%opt );

$opt{tags}       = exists $opt{t} ? [ split ',', $opt{t} ] : [];
$opt{categories} = exists $opt{c} ? [ split ',', $opt{c} ] : [];
$opt{chapters}   = exists $opt{i}
    ? [
    map {
        my ( $s, $e ) = split '-', $_;
        $e ||= $s;
        ( $s .. $e )
    } ( split ',', $opt{i} )
    ]
    : [];

my $mech = init_wordpress_agent();
post_book_to_wordpress( $mech, \%opt );

sub init_wordpress_agent {
    my ( $site, $user, $passwd ) = @_;
    my $o = WordPress::XMLRPC->new(
        {   username => $user   || $USER,
            password => $passwd || $PASSWD,
            proxy    => $site   || $WORDPRESS,
        }
    );
    return $o;
}

sub post_book_to_wordpress {
    my ( $mech, $opt ) = @_;
    my $file = $opt->{f};

    print "start post $file\n";
    if ( !@{ $opt->{chapters} } ) {
        my $num =
            $file =~ /\.zip$/
            ? read_chapter_num_zip($file)
            : read_chapter_num_html($file);
        $opt->{chapters} = [ 1 .. $num ];
    }
    my $num = scalar( @{ $opt->{chapters} } );
    for my $i ( 0 .. $#{ $opt->{chapters} } ) {
        my $j = $i + 1;
        print "\rpost $j / $num";
        my $d =
            $file =~ /\.zip$/
            ? read_chapter_data_zip( $file, $opt->{chapters}[$i] )
            : read_chapter_data_html( $file, $opt->{chapters}[$i] );
        next unless ($d);
        push @{ $d->{tags} }, @{ $opt->{tags} } if ( @{ $opt->{tags} } );
        push @{ $d->{categories} }, @{ $opt->{categories} }
            if ( @{ $opt->{categories} } );
        post_to_wordpress( $mech, $d );
    }
    print "\nfinish post $file\n";
}

sub read_chapter_num_zip {
    my ($zip) = @_;
    my $num = `als '$zip'|grep 'html\$' |grep -v '000.html'|wc -l`;
    chomp $num;
    return $num;
}

sub read_chapter_num_html {
    my ($zip) = @_;
    my $num = `cat '$zip'|grep '<a href="#toc' |wc -l`;
    chomp $num;
    return $num;
}

sub read_chapter_data_zip {
    my ( $zip, $i ) = @_;
    my $f = sprintf( "%03d.html", $i );
    my $html = `acat '$zip' $f`;
    return unless ( $html and $html !~ /\[锁\]/s );
    my ( $writer, $book, $title ) = $html
        =~ m#<title>\s*(\S.*?)\s*\n\s*《(\S.*?)》\s*\n\s*(\S.*?)\s*</title>#s;
    my ($href) = $html =~ m#<div id="title">.*?href="(.*?)"#s;
    my ($content) =
        $html =~ m#<div id="content">(.+?)</div>\s*<div id="footer"#s;
    my %data = (
        'title' => qq[$writer 《$book》 $i : $title],
        'content' =>
            qq[<p>来自：<a href="$href">$href</a></p><p></p>$content],
        'tags' => [ $writer, $book ],
    );
    return \%data;
}

sub read_chapter_data_html {
    my ( $zip, $i ) = @_;
    my $html = `cat '$zip'`;
    return unless ($html);

    my ( $writer, $book ) =
        $html =~ m#<title>\s*(\S.*?)\s*《(\S.*?)》\s*</title>#s;

    my $f = sprintf( "%03d", $i );
    my ( $title, $content ) = $html
        =~ m{<div class="fltitle">$f\# <a name="toc$i">(.*?)</a></div>\s*<div class="flcontent">(.+?)</div>\s*</div>}s;

    my %data = (
        'title'   => qq[$writer 《$book》 $i : $title],
        'content' => $content,
        'tags'    => [ $writer, $book ],
    );
    return \%data;
}

sub post_to_wordpress {

    my ( $o, $data ) = @_;

    my %form = (
        title       => $data->{title},
        description => $data->{content},
        mt_keywords => $data->{tags},
        categories  => $data->{categories},
    );

    $o->newPost( \%form, 1 );
}
