#===============================================================================
#  DESCRIPTION:  模拟浏览器，获取网页内容
#       AUTHOR:  AbbyPan (USTC), <abbypan@gmail.com>
#===============================================================================
package Novel::Browser;
use strict;
use warnings;
use utf8;

use IO::Uncompress::Gunzip qw(gunzip $GunzipError);
use Encode qw/encode decode/;
use Encode::Detect::CJK qw/detect/;
use HTTP::Tiny;
use Fatal qw/open close/;

use Moo;
has retry => ( is => 'rw', default => sub {3}, );

sub get_url_ref {
    my ( $self, $url, $post_vars ) = @_;

    my $http = $self->init_browser();

    my $response;
    for my $i ( 1 .. $self->{retry} ) {

        if ($post_vars) {
            my $post_data = $self->make_post_data($post_vars);
            $response = $http->request( 'POST', $url, $post_data );
        }
        else {
            $response = $http->get($url);
        }

        last if ( $response->{success} );
    } ## end for my $i ( 1 .. $self->...)

    return unless ( $response->{success} );

    my $html;
    gunzip \$response->{content} => \$html;

    my $charset = detect($html);
    $html = decode( $charset, $html, Encode::FB_XMLCREF );

    return \$html;
} ## end sub get_url_ref

sub init_browser {
    my ($self) = @_;
    my %browser_opt = (
        default_headers => {
            'Accept'          => 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
            'Accept-Charset'  => 'gb2312,utf-8;q=0.7,*;q=0.7',
            'Accept-Encoding' => "gzip, deflate",
            'Connection'      => 'keep-alive',
            'User-Agent' =>
                'Moozilla/5.0 (compatible; MSIE 9.0; Windows NT 6.1; Trident/5.0; MALC)',
            'Accept-Language' => "zh,zh-cn;q=0.8,zh-tw;q=0.6,en-us;q=0.4,en;q=0.2",
        },
    );
    my $http = HTTP::Tiny->new(%browser_opt);

    return $http;
} ## end sub init_browser

sub make_post_data {
    my ( $self, $post_vars ) = @_;

    my @params;
    while ( my @pair = each %$post_vars ) {
        push @params, join( "=", @pair );
    }

    my $data = {
        content => join( "&", @params ),
        headers => { 'content-type' => 'application/x-www-form-urlencoded' }
    };

    return $data;
} ## end sub make_post_data

sub get_url {
    my ( $self, $url, $filename ) = @_;

    my $http = new HTTP::Tiny;

    my $res;
    for my $i ( 1 .. $self->{retry} ) {
        $res = $http->get($url);
        last if ( $res->{success} );
    }

    return unless ( $res->{success} );

    open my $fh, ">:raw", $filename;
    print $fh $res->{content};
    close $fh;

    return 1;
} ## end sub get_url

no Moo;
1;

