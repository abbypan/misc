#!/usr/bin/perl 
#===============================================================================
#  DESCRIPTION:  下载论坛贴子(目前支持DISCUZ，备份CJJ)
#       AUTHOR:  Abby Pan (abbypan@gmail.com), USTC
#      CREATED:  2011/2/19 1:35:54
#===============================================================================

use strict;
use warnings;

use URI::URL;
use LWP::UserAgent;
use HTTP::Response::Encoding;
use Cwd;
use File::Slurp qw/write_file/;
use Encode qw/encode decode/;
use HTML::Template::Expr;
use Getopt::Std;
use utf8;
use vars qw/%OPT $LOCALE $CHARSET $BROWSER %THREAD %FORUM/;
$| = 1;

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
push @{ $BROWSER->requests_redirectable }, 'POST';

#读入站点信息
getopt( 'upsftUT', \%OPT );

#帮助信息
print_usage() unless ( $OPT{s} );

#登录站点
login( $OPT{s}, $OPT{u}, $OPT{p} );

#下载或者更新贴子
if ( $OPT{t} ) {
    get_thread( $OPT{s}, $OPT{t} );
}
elsif ( $OPT{f} ) {
    get_forum( $OPT{s}, $OPT{f} );
}
else {
    get_site( $OPT{s} );
}

#########################

sub get_site {
    my ($site) = @_;

    my $html_ref = get_one_url($site);
    my $title    = parse_site_title($html_ref);
    my $fids     = parse_subforum($html_ref);
    print "site: $title\n";

    my $cwd_dir = getcwd();
    my $dir = encode( $LOCALE, $title );
    mkdir($dir);
    chdir($dir);
    get_forum( $site, $_ ) for @$fids;
    chdir($cwd_dir);
}

sub parse_site_title {
    my ($html_ref) = @_;
    my ($title) = $$html_ref =~ /<a\s*href="index.php"\s*>(.*?)<\/a>/s;
    return $title;
}

#########################

sub make_forum_url {
    my ( $site, $fid, $num ) = @_;
    return "$site/forum-$fid-$num.html";
}

sub parse_forum_title {
    my ($html_ref) = @_;
    my ($title) = $$html_ref =~ /<h1>(.*?)<\/h1>/s;
    return $title;
}

sub parse_forum_tids {
    my ($html_ref) = @_;
    my @tids = $$html_ref =~ /<tbody\s*id="normalthread_(\d+)"\s*>/isg;
    return \@tids;
}

sub parse_subforum {
    my ($html_ref) = @_;
    return
      unless (
        $$html_ref =~ m#<h3>子版块<\/h3>|</a>\s*&raquo;\s*首页</div>#s );
    my @fids = $$html_ref =~ /<a href="forum-(\d+)-1.html"\s*>/sg;
    return \@fids;
}

sub get_forum {
    my ( $site, $fid ) = @_;

    return if(exists $FORUM{$fid});
    $FORUM{$fid} = 1;

    my $url         = make_forum_url( $site, $fid, 1 );
    my $html_ref    = get_one_url($url);
    my $forum_title = parse_forum_title($html_ref);
    my $forum_pages = parse_page_num($html_ref);
    my $tids        = parse_forum_tids($html_ref);
    my $subforums   = parse_subforum($html_ref);

    for my $i ( 2 .. $forum_pages ) {
        my $i_url = make_forum_url( $site, $fid, $i );
        my $i_h   = get_one_url($i_url);
        my $i_t   = parse_forum_tids($i_h);
        push @$tids, @$i_t;
    }

    #use Data::Dumper;
    #print Dumper($subforums);exit;
    print "\nforum : $forum_title\n";
    my $cwd_dir = getcwd();
    my $forum_dir = encode( $LOCALE, $forum_title );
    mkdir($forum_dir);
    chdir($forum_dir);
    my @htmls = glob("*.html");
    unless(@htmls){
        get_thread( $site, $_ ) for @$tids;
    }
    if ($subforums) {
        get_forum( $site, $_ ) for @$subforums;
    }
    chdir($cwd_dir);
}

#########################

sub parse_page_num {
    my ($html_ref) = @_;
    my ($pages) = $$html_ref =~ m#<div class="pages">(.*?)</div>#s;
    return 1 unless ($pages);
    my ($page_num) = $pages =~ m#>[. ]*(\d+)</a>\s*<a[^>]*class="next"#s;
    return $page_num;
}

sub get_thread {
    my ( $site, $tid ) = @_;
    
    return if(exists $THREAD{$tid});
    $THREAD{$tid} = 1;

    my $url       = make_thread_url( $site, $tid, 1 );
    my $html_ref  = get_one_url($url);
    my $floor_ref = parse_floor($html_ref);
    return unless ( defined $floor_ref );
    my $post_ref;
    $post_ref->{url} = $url;

    my $page_num = parse_page_num($html_ref);
    for my $i ( 2 .. $page_num ) {
        my $i_url   = make_thread_url( $site, $tid, $i );
        my $i_r     = get_one_url($i_url);
        my $i_floor = parse_floor($i_r);
        push @{$floor_ref}, @{$i_floor};
    }
    $floor_ref->[$_]{id} = $_ for ( 0 .. $#$floor_ref );

    $post_ref->{floor} = $floor_ref;
    $post_ref->{name}  = $floor_ref->[0]{name};
    $post_ref->{title} = $floor_ref->[0]{title};
    $post_ref->{time}  = $floor_ref->[0]{time};

    unless ( $post_ref->{title} ) {
        my ($nav) = $$html_ref =~ m#<div\s*id="nav"\s*>(.*?)</div>#s;
        ( $post_ref->{title} ) = $nav =~ m#&raquo;\s*([^>]+)$#s;
    }

    my $filename;
    for ( $post_ref->{name}, $post_ref->{title} ) {
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

sub parse_floor {
    my ($html_ref) = @_;
    my @floor;
    for ($$html_ref) {

        #去掉乱码
        s#<font style="font-size:0px;color:\#[F]{3,6}">.*?</font>##gis;
        s#<span style="display:none">.*?</span>##gis;
        s#<font style="font-size:0px;color:\#DAF4DD">.*?</font>##gis;

        #去掉系统表情
        s#<img src="images/[^>]*>##gi;
        s#&quot; /&gt;##gi;

        #去掉乱七八糟的字体样式
        s#</?font[^>]*>##gis;
        s#</?blockquote>##gis;

        #分割各楼内容
        while (m#(<div id="post_\d+">.*?</table>\s*</div>)#gis) {
            my $cell = $1;
            my %fl;
            ( $fl{name} ) =
              $cell =~ m#href="space.php\?uid=\d+"[^>]*>(.*?)</a>#s;
            unless ( $fl{name} ) {
                ( $fl{name} ) =
                  $cell =~ m#<div class="avatar">\s*(.*?)\s*<em>#s;
            }
            ( $fl{time} ) =
              $cell =~ m#<em id="authorposton\d+">发表于 (.*?)</em>#s;
            ( $fl{content} ) = $cell =~
m{<td[^>]*class="t_msgfont"[^>]*>(.*?)</td>\s*</tr>\s*</table>\s*</div>}s;
            ( $fl{title} ) =
              $cell =~ m{<div id="threadtitle">\s*<h1>(.*?)</h1>}s;
            push @floor, \%fl;

            #        print $cell;
            #use Data::Dumper;
            #print Dumper(\%fl);exit;
        }

    }
    return \@floor;
}

sub make_thread_url {
    my ( $site, $tid, $page ) = @_;
    return "$site/viewthread.php?tid=$tid&page=$page";
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

#########################

sub get_one_url {
    my ($url) = @_;
    print "\rget : $url";
    my $response = $BROWSER->get($url);
    my $enc      = $CHARSET || $response->charset;
    my $html     = decode( $enc, $response->content );
    return \$html;
}

sub login {
    my ( $domain, $user, $passwd ) = @_;

    my $login = url( $domain . '/logging.php?action=login' );
    my %form =
      ( 'username' => $user, 'password' => $passwd, 'loginsubmit' => 'true' );

    my $response = $BROWSER->post( $login, \%form );
    $CHARSET = $response->charset;
    return;
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

sub print_usage {
    my $usage = <<__USAGE__;
举例：
下载贴子：./tiezi.pl -s http://xxx.xxx.xxx -u username -p password -t 123 
下载版块：./tiezi.pl -s http://xxx.xxx.xxx -u username -p password -f 45 
下载论坛：./tiezi.pl -s http://xxx.xxx.xxx -u username -p password

参数说明：
-s : 指定论坛地址
-u : 指定用户名
-p : 指定密码
-t : 指定下载的贴子号
-f : 指定下载的版块号
-T : 生成的贴子不加楼层目录(默认是加楼层目录)
-U : 只看楼主(默认是取出所有楼层，不只楼主)
__USAGE__
    print $usage;
    exit;
}
