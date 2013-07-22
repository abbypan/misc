#!/usr/bin/perl 
#===============================================================================
#  DESCRIPTION: 自动发贴到百度空间(需要先手工取出cookie和发贴表单中的bdstoken)
#       AUTHOR: Abby Pan (USTC), abbypan@gmail.com
#      CREATED: 2012年11月04日 20时08分54秒
#===============================================================================

use strict;
use warnings;

use WWW::Mechanize;

our $COOKIE = 'xxx';
our $BDSTOKEN = 'xxx';

my $mech = init_baidu_browser();
my $data = {
    'title'   => 'my title',
    'content' => 'just test',
    'tags'    => ['tagx','tagy'],
};
post_to_baidu($mech, $data);

sub post_to_baidu {

    my ( $mech, $data ) = @_;

    my @form = (
        refer    => 'http://hi.baidu.com/home',
        private1 => 1,
        private  => 1,
        imgnum   => 0,
        title    => $data->{title},
        content  => $data->{content},
        bdstoken => $data->{bdstoken} || $mech->{bdstoken},
    );

    push @form, ( 'tags[]', $_ ) for @{ $data->{tags} };

    $mech->post( 'http://hi.baidu.com/pub/submit/createtext', \@form );
}

sub init_baidu_browser {
    my ( $cookie, $bdstoken ) = @_;

    my $mech = WWW::Mechanize->new();

    $mech->{bdstoken} = $bdstoken || $BDSTOKEN;
    $mech->add_header( 'Cookie' => $cookie || $COOKIE );

    $mech->add_header( 'User-Agent' =>
            'Mozilla/5.0 (X11; Linux x86_64; rv:16.0) Gecko/20100101 Firefox/16.0'
    );
    $mech->add_header( 'Accept' =>
            'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8'
    );
    $mech->add_header( 'Accept-Language' => 'en-US,en;q=0.5' );
    $mech->add_header( 'Accept-Encoding' => 'gzip, deflate' );
    $mech->add_header( 'Connection'      => 'keep-alive' );
    $mech->add_header( 'Content-Type' =>
            'application/x-www-form-urlencoded; charset=UTF-8' );
    $mech->add_header( 'X-Requested-With' => 'XMLHttpRequest' );
    $mech->add_header(
        'Referer' => 'http://hi.baidu.com/pub/show/createtext' );
    $mech->add_header( 'Pragma'        => 'no-cache' );
    $mech->add_header( 'Cache-Control' => 'no-cache' );

    return $mech;
}
