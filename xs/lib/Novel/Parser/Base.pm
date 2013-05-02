#===============================================================================
#  DESCRIPTION:  各站点的解析引擎
#       AUTHOR:  AbbyPan (USTC), <abbypan@gmail.com>
#===============================================================================
package  Novel::Parser::Base;
use strict;
use warnings;
use Moo;

has domain => (

    #网站基地址
    is => 'rw',
);

has site => (

    #网站名称
    is => 'rw',
);

has charset => (

    is => 'rw',
);

sub get_elem_html {
    my ( $self, $elem ) = @_;

    my $_ = $elem->as_HTML('<>&');

    my $head_i = index( $_, '>' );
    substr( $_, 0, $head_i + 1 ) = '';

    my $tail_i = rindex( $_, '<' );
    substr( $_, $tail_i ) = '';

    return $_;
} ## end sub get_elem_html

sub alter_index_before_parse {

    #解析index内容之前，先做一些简单文本处理
}

sub alter_chapter_before_parse {

    #解析chapter内容之前，先做一些简单文本处理
}

sub get_query_result_urls {

    #查询结果为多页时，取得除第1页之外的其他结果页面的url
}

no Moo;
1;
