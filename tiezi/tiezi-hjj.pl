#!/usr/bin/perl 
#===============================================================================
#  DESCRIPTION:  下载红晋江论坛帖子
#       AUTHOR:  Abby Pan (abbypan@gmail.com), USTC
#      CREATED:  2012/2/3 22:08:03
#===============================================================================

use strict;
use warnings;

use LWP::UserAgent;
use Cwd;
use File::Slurp qw/write_file/;
use Encode qw/encode decode/;
use HTML::Template::Expr;
use Getopt::Std;
use utf8;
use vars qw/%OPT $LOCALE $CHARSET $BROWSER %THREAD %board/;
$| = 1;

our $SITE = 'http://bbs.jjwxc.net';

#本地编码
$LOCALE = $^O ne 'MSWin32' ? 'utf8' : 'cp936';
binmode( STDIN,  ":encoding($LOCALE)" );
binmode( STDOUT, ":encoding($LOCALE)" );
binmode( STDERR, ":encoding($LOCALE)" );

#站点编码
$CHARSET = 'cp936';

#初始化浏览器
$BROWSER = LWP::UserAgent->new( keep_alive => 1 );
$BROWSER->cookie_jar( {} );

#读入站点信息
getopt( 'zbtUT', \%OPT );

#帮助信息
print_usage() unless ( $OPT{z} || $OPT{b});


#下载或者更新贴子
if ( $OPT{t} ) {
    get_thread( $OPT{b}, $OPT{t} );
}
elsif ( $OPT{b} ) {
    get_board( $OPT{b} );
}
else {
    get_zone( $OPT{z} );
}

### usage 

sub print_usage {
    my $usage = <<__USAGE__;
举例：
下载贴子：./tiezi-hjj.pl -b 14 -t 23205
下载版块：./tiezi-hjj.pl  -b 14 
下载论坛：./tiezi-hjj.pl -z 1 

参数说明：
-z : 指定下载的讨论区
-b : 指定下载的版块号
-t : 指定下载的贴子号
-T : 生成的贴子不加楼层目录(默认是加楼层目录)
-U : 只看楼主(默认是取出所有楼层，不只楼主)
__USAGE__
    print $usage;
    exit;
}

###  thread

sub get_thread {
    my ( $board, $tid ) = @_;
    
    return if(exists $THREAD{$tid});
    $THREAD{$tid} = 1;

    my $url       = make_thread_url( $board, $tid );
    my $html_ref  = get_one_url($url);
    my $floor_ref = parse_thread_floors($html_ref);
    return unless ( defined $floor_ref );
    my $post_ref;
    $post_ref->{url} = $url;

    my $page_num = parse_thread_pagenum($html_ref);
    for my $i ( 1 .. $page_num ) {
        my $i_url   = make_thread_url( $board, $tid, $i );
        my $i_r     = get_one_url($i_url);
        my $i_floor = parse_thread_floors($i_r);
        push @{$floor_ref}, @{$i_floor};
    }
    $floor_ref->[$_]{id} = $_ for ( 0 .. $#$floor_ref );

    $post_ref->{floor} = $floor_ref;
    $post_ref->{name}  = $floor_ref->[0]{name};
    $post_ref->{title} = $floor_ref->[0]{title};
    $post_ref->{time}  = $floor_ref->[0]{time};

    my $filename;
    for ( $post_ref->{name}, $post_ref->{title} ) {
		s/=/＝/g;
        s/[[:punct:] ]*//g;
    }
    $filename = $post_ref->{name} . "-" . $post_ref->{title} . ".html";
    $filename = encode( $LOCALE, $filename );
    print
      "\nthread : $post_ref->{name}, $post_ref->{title}, $post_ref->{time}\n\n";

    my $html = make_thread_html($post_ref);

    eval {
        my $i = write_file( $filename, $html );
        write_file( $tid . ".html", $html ) unless ($i);
    }

}


sub make_thread_url {
    my ( $board, $tid, $page ) = @_;
	my $url = "$SITE/showmsg.php?board=$board&id=$tid";
	$url .= "&page=$page" if($page);
	return $url;
}

sub get_one_url {
    my ($url) = @_;
    print "\rget : $url";
    my $response = $BROWSER->get($url);
    my $enc      = $CHARSET || $response->charset;
    my $html     = decode( $enc, $response->content );
    return \$html;
}

sub parse_thread_floors {
    my ($html_ref) = @_;
    my @floor;
    for ($$html_ref) {
		#取出顶楼
		my %top_fl;
		($top_fl{title})= 
		m{<td bgcolor="#E8F3FF"><div style="float: left;">\s*主题：(.+?)<font color="#999999" size="-1">}s;
($top_fl{content}) = m{<td class="read"><div id="topic">(.*?)</div>\s*</td>\s*</tr>\s*</table>}s;
            ( $top_fl{name}, $top_fl{time} ) =
              m#№0&nbsp;</font>.*?☆☆☆</font>(.*?)</b><font color="99CC00">于</font>(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})留言#s;
			  $top_fl{name}=~s/<\/?(font|b).*?>//gsi;
		  push @floor , \%top_fl;
		

        #分割各楼内容
        while (m#(<tr>\s+<td colspan="2">.*?<td><font color=99CC00 size="-1">.*?</tr>)#gis) {
            my $cell = $1;
			next unless($cell);

            my %fl;

            ( $fl{name}, $fl{time} ) =
              $cell =~ m#☆☆☆</font>(.*?)</b><font color="99CC00">于</font>(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})留言#s;
			  $fl{name}=~s/<\/?(font|b).*?>//gsi;

            ( $fl{content} ) = $cell =~
			m{<tr>\s*<td[^>]*class="read">\s*(.*?)\s*</td>\s*</tr>\s*</table>}s;
			$fl{title} = '';
            push @floor, \%fl;
        }

    }
    return \@floor;
}

sub parse_thread_pagenum {
    my ($html_ref) = @_;
    my ($pages) = $$html_ref =~ m#<div id="pager_top".*?&page=(\d+)>尾页</a></div>#s;
	return $pages || 0;
}

sub make_thread_html {
    my ($post_ref) = @_;

    if ( exists $OPT{U} ) {

        #只看楼主
        for my $fl ( @{ $post_ref->{floor} } ) {
            delete( $fl->{content} ) if ( $fl->{name} ne $post_ref->{name} );
        }
    }

    unless ( exists $OPT{T} ) {

        #默认生成楼层目录
        $post_ref->{toc} = "";
        for my $fl ( @{ $post_ref->{floor} } ) {
            next unless ( exists $fl->{content} );
            print "error : $fl->{id}, $fl->{name}, $fl->{time}\n"
              unless ( defined $fl->{id}
                and defined $fl->{name}
                and defined $fl->{time} );
            $post_ref->{toc} .=
qq[<li><a href="#toc$fl->{id}">$fl->{id}#  $fl->{name} $fl->{time}</a></li>\n];
        }
        $post_ref->{toc} =~ s/^/<ul>/;
        $post_ref->{toc} =~ s{$}{</ul>\n};
    }

    my $tmpl =
'<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01//EN" "http://www.w3.org/TR/html4/strict.dtd">
    <html>
    <head>
    <meta http-equiv="Content-Type" content="text/html; charset=utf-8">
    <title>
    <TMPL_IF NAME=title><TMPL_VAR NAME=title></TMPL_IF>
    </title>
    <style type="text/css">
    <TMPL_IF NAME=css><TMPL_VAR NAME=css></TMPL_IF>
    </style>
    </head>
    <body>
    <h1><a id="url" href="<TMPL_VAR NAME=url>"><span id="title"><TMPL_VAR NAME=title></span></a></h1>
    <h2 id="time"><TMPL_VAR NAME=time></h2>


    <TMPL_IF NAME=toc>
    <TMPL_VAR NAME=toc>

    <TMPL_LOOP NAME=floor>
    <TMPL_IF NAME=content>
    <div class="floor">
    <h3><a name="toc<TMPL_VAR NAME=id>"><TMPL_VAR NAME=id>#  <span class="floor_name"><TMPL_VAR NAME=name></span>  <span class="floor_time"><TMPL_VAR NAME=time></span></a></h3>
    <div class="floor_content"><TMPL_VAR NAME=content></div>
    </div>
    </TMPL_IF>
    </TMPL_LOOP>

    <TMPL_ELSE>

    <TMPL_LOOP NAME=floor>
    <TMPL_IF NAME=content>

    <div class="floor">
    <h3><TMPL_VAR NAME=id>#  <span class="floor_name"><TMPL_VAR NAME=name></span>  <span class="floor_time"><TMPL_VAR NAME=time></span></h3>
    <div class="floor_content"><TMPL_VAR NAME=content></div>
    </div>
    </TMPL_IF>

    </TMPL_LOOP>
    </TMPL_IF>

    </body>
    </html>';

    my $template = HTML::Template::Expr->new(
        'scalarref'         => \$tmpl,
        'die_on_bad_params' => '0'
    );

    $post_ref->{css} ||= gen_css();
    while ( my ( $k, $v ) = each %$post_ref ) {
        $template->param( $k => $v );
    }
    my $html = $template->output;
    for ($html) {
        s#([^><]+)(<br\s*/?\s*>\s*){1,}#<p>$1</p>\n#g;
        s#(\n[ \t]*){3,}#\n\n#gs;
    }
    $html = encode( 'utf8', $html );

    return \$html;

}

sub gen_css {

    return 'body {
    font-size: medium;
    font-family: Verdana, Arial, Helvetica, sans-serif;
    margin: .5em 2em .5em 2em;
    line-height:150%;
    }
    p { text-indent:2em; }
    h1 {font-size:x-large;line-height:130%;text-align:center; }
    h1 a {text-decoration:none; }
    h3 {
    border-top: .2em solid #ee9b73;
    padding-top: .8em;
    margin: 1em 0em 1em 0em;
    text-indent:0em;
    font-size:medium;
    }
    ul {line-height:150%;padding-top:1em;border-top:.2em solid #EE9B73;}
    li { margin-left: 2em;}';
}

### board 

sub get_board {
    my ( $fid ) = @_;

    return if(exists $board{$fid});
    $board{$fid} = 1;

    my $url         = make_board_url( $fid, 1 );
    my $html_ref    = get_one_url($url);
    my $board_title = parse_board_title($html_ref);
    my $board_pages = parse_board_pagenum($html_ref);
    my $tids        = parse_board_tids($html_ref);

    for my $i ( 2 .. $board_pages ) {
        my $i_url = make_board_url( $fid, $i );
        my $i_h   = get_one_url($i_url);
        my $i_t   = parse_board_tids($i_h);
        push @$tids, @$i_t;
    }

    print "\nboard : $board_title\n";
    my $cwd_dir = getcwd();
    my $board_dir = encode( $LOCALE, $board_title );
    mkdir($board_dir);
    chdir($board_dir);
    my @htmls = glob("*.html");
    unless(@htmls){
        get_thread( $fid, $_ ) for @$tids;
    }

    chdir($cwd_dir);
}

sub make_board_url {
    my ( $fid, $num ) = @_;
    return "$SITE/board.php?board=$fid&page=$num";
}

sub parse_board_title {
    my ($html_ref) = @_;
    my ($title) = $$html_ref =~m#<table width="760" border="0" align="center" cellpadding="0" cellspacing="0">\s*<tr>\s*<td>(.*?)</td>\s*</tr>\s*</table>#s;
    return $title;
}

sub parse_board_pagenum {
    my ($html_ref) = @_;
    my ($pages) = $$html_ref =~ m{<td align="right">\s*共<font color="#FF0000">(\d+)</font>页　当前为第}s;
	return $pages || 1;
}

sub parse_board_tids {
    my ($html_ref) = @_;
    my @tids = $$html_ref =~ /<td><a\s+href="showmsg.php\?board=\d+&id=(\d+)&msg=/isg;
    return \@tids;
}


### zone

sub get_zone {
    my ($zone) = @_;

	my $url = make_zone_url($zone);
    my $html_ref = get_one_url($url);
    my $title    = parse_zone_title($html_ref);
    my $fids     = parse_zone_boards($html_ref);
    print "zone: $title\n";

    my $cwd_dir = getcwd();
    my $dir = encode( $LOCALE, $title );
    mkdir($dir);
    chdir($dir);
    get_board( $_ ) for @$fids;
    chdir($cwd_dir);
}

sub make_zone_url {
	my ($zone) = @_;
	$zone ||=0;
	return "$SITE/index$zone.htm";

}

sub parse_zone_title {
    my ($html_ref) = @_;
    my ($title) = $$html_ref =~m{<a\s+href="bindex.php\?class=\d+"\s*>\s*<b>\s*<em>\s*<font.*?>\s*(.+?)\s*</font>\s*</em>\s*</b>\s*</a>\s*</td>}si;
    return $title;
}

sub parse_zone_boards {
    my ($html_ref) = @_;
    my @fids = $$html_ref =~ /<center>\s*<a href="board.php\?board=(\d+)&page=1">/sg;
    return \@fids;
}
