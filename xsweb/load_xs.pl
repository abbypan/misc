#!/usr/bin/perl 
#===============================================================================
#         FILE:  load_xs.pl
#        USAGE:  ./load_xs.pl  
#  DESCRIPTION:  导入数据库
#       AUTHOR:  Abby Pan (USTC), abbypan@gmail.com
#      VERSION:  1.0
#      CREATED:  2011年01月09日 18时34分37秒
#===============================================================================
use strict;
use warnings;

our $VERSION = 0.1;

use  Archive::Zip;
use  HTML::TreeBuilder;
use  HTML::FormatText;
use  Encode;
#use Encode::Detect::CJK qw/detect/;
use File::Slurp qw/slurp write_file/;
use utf8;
use DBI;
use Web::Scraper;
use Data::Dumper;
$|=1;

#本地编码处理
our $LOCALE = $^O eq 'MSWin32' ? 'cp936' : 'utf8';
#binmode( STDIN,  ":encoding($LOCALE)" );
#binmode( STDOUT, ":encoding($LOCALE)" );
#binmode( STDERR, ":encoding($LOCALE)" );

#目标txt文件的编码
our $DST_CHARSET= 'utf8';

my ($file) = @ARGV;
unless(-f $file){
    print "please input one file\n";
    exit;
}

my $info = 
$file=~/\.zip$/?
read_info_from_zip($file):
read_info_from_html($file);

load_book_into_db($info);

sub load_book_into_db {
    my ($info) = @_;
#    print Dumper($info->{intro});exit;
    return unless($info);
    my $writer = $info->{writer};
    $info->{writer_id} = check_writer($writer);
    $info->{id} = check_book($info->{writer_id}, $info->{name});

    print "insert book info\n";
    my @keys = ('site','url','word_num','chapter_num','series','intro','cover','time');
    my $keys_str = join(",", map { $_.' = ? ' } @keys);
    our $DBH = DBI->connect('dbi:Pg:dbname=xs','xswrite','xsadmin');
    my $sql = qq[update book set $keys_str where id=$info->{id} and
    writer_id=$info->{writer_id} and name='$info->{name}'];
    my $sth=$DBH->prepare($sql);
    $sth->execute(@{$info}{@keys});

    print "insert chapter content\n";
    for my $chap (@{ $info->{chapter_info}}){
        my @chap_keys = ('book_id','title','id','volume','url','content','time','writer_say','type');
        $chap->{book_id}=$info->{id};
        print "\rinsert $chap->{id} chapter";
        my $keys_str = join(",", @chap_keys);
        my $values_str = join(",", ('?') x scalar(@chap_keys));
        my $sql = qq[ insert into chapter($keys_str) values($values_str) ];
        my $sth=$DBH->prepare($sql);
        $sth->execute(@{$chap}{@chap_keys});
    }
}

sub check_writer {
    my ($writer) = @_;
    our $DBH = DBI->connect('dbi:Pg:dbname=xs','xswrite','xsadmin');
    WRITER_LABEL:

    my $sql=qq[select id from writer where name=?;];
    my $sth=$DBH->prepare($sql);
    $sth->execute($writer);
    my @row_ary  = $sth->fetchrow_array;
    my $writer_id;
    if(@row_ary){
        $writer_id = $row_ary[0];
    }else{
        $DBH->do(qq[insert into writer(name) values('$writer')]);
        goto WRITER_LABEL;
    }
    return $writer_id;
}

sub check_book {
    my ($writer_id, $name) = @_;
    our $DBH = DBI->connect('dbi:Pg:dbname=xs','xswrite','xsadmin');
    BOOK_LABEL:

    my $sql=qq[select id from book where writer_id=? and name=?;];
    my $sth=$DBH->prepare($sql);
    $sth->execute($writer_id, $name);
    my @row_ary  = $sth->fetchrow_array;
    my $book_id;
    if(@row_ary){
        $book_id = $row_ary[0];
    }else{
        $DBH->do(qq[insert into book(writer_id, name)
            values('$writer_id','$name')]);
        goto BOOK_LABEL;
    }
    return $book_id;
}


sub read_info_from_zip {
    our $INDEX_SCRAPER_YQ = scraper {
        process_first '#site', 'site' => sub { $_[0]->as_trimmed_text };
        process_first '#book',
        'url' => sub { $_[0]->attr('href') },
        'name'      => sub { $_[0]->as_trimmed_text };
        process_first '#date', 'time' => 'TEXT';
        process_first '#writer', 'writer' => sub { $_[0]->as_trimmed_text };
        process_first '#intro', 'intro' => sub { $_=$_[0]->as_HTML('<>&');
            s/^<div.*?>//s;s#(<br />)*(&gt;\s*)*</div>$##s; 
            my $temp=s#^\s*<b>\s*[^<]*</b>\s*<div id="intro">##s;
            s#</div>\s*$##s if($temp);
            $_;
        };
        process_first '#cover',
        'cover' => sub { my @imgs=$_[0]->look_down('_tag', 'img');
            $imgs[0]->attr('src') },
        process_first '#series', 'series' => sub { $_[0]->as_trimmed_text };
        process '#chapter_info', 'chapter_info' => sub {
            my @update_time;
            my @trs = $_[0]->look_down( '_tag', 'li' );
            for my $tr (@trs){
                my @tds = $tr->look_down( '_tag', 'a' );
                next unless(@tds);
                my $link = $tds[0];
                my $title = $link->as_trimmed_text;
                my ($id) = $link->attr('href')=~/0*(\d+).html/;
                push @update_time, { 
                    'id'=> $id, 'title'=>$title, 
                };
            }
            return \@update_time;
    };
    result 'site', 'url', 'name', 'writer', 'series'
    , 'intro', 'cover', 'time'
    , 'chapter_info'
    ;
};
our $INDEX_SCRAPER = scraper {
    process_first '#site', 'site' => sub { $_[0]->as_trimmed_text };
    process_first '#book',
    'url' => sub { $_[0]->attr('href') },
    'name'      => 'TEXT';
    process_first '#writer', 'writer' => 'TEXT';
    process_first '#intro', 'intro' => sub { $_=$_[0]->as_HTML('<>&');
        s/^<div.*?>//s;s#(<br />)*</div>$##s; 
        $_;
    };
    process_first '#cover',
    'cover' => sub { my @imgs=$_[0]->look_down('_tag', 'img');
        $imgs[0]->attr('src') },
    process_first '#word_num', 'word_num' => sub { my $num
        =$_[0]->as_trimmed_text; $num=~s/\D+$//; return $num };
    process_first '#series', 'series' => sub { $_[0]->as_trimmed_text };
    process_first '#chapter_num',
    'chapter_num' => sub { $_[0]->as_trimmed_text };
    process '#chapter_info', 'chapter_info' => sub {
        my @update_time;
        my @trs = $_[0]->look_down( '_tag', 'tr' );
        for my $tr (@trs){
            my @tds = $tr->look_down( '_tag', 'td' );
            next unless(@tds);
            next unless($tds[1]);
            my $id = $tds[0]->as_trimmed_text;
            my $title = $tds[1]->as_trimmed_text;
            my @chaps_info = $tr->look_down( 'class', 'update_time' );
            for my $chap (@chaps_info) {
                my $time = $chap->as_trimmed_text;
                my $type = $chap->attr('type');
                push @update_time, { 'time' => $time, 'type' => $type,
                    'id'=> $id, 'title'=>$title, 
                };
            } ## end for my $chap (@chaps_info)
        }
        return \@update_time;
};
result 'site', 'url', 'name', 'writer', 'series', 'chapter_num'
,'word_num', 'intro', 'cover'
, 'chapter_info'
;
};

our $CHAPTER_SCRAPER = scraper {
    process_first '#chapter',
    'url' => sub { $_[0]->attr('href') },
    'title'      => 'TEXT';
    process_first '#content', 'content' => sub { 
        $_=$_[0]->as_HTML('<>&');
        s/^<div.*?>//s;s#(<br />)*(&gt;\s*)*</div>$##s; 
        $_;
    };
    process_first '#writer_say', 'writer_say' => sub { 
        $_=$_[0]->as_HTML('<>&');
        s/^<div.*?>//s;s#(<br />)*</div>$##s; 
        $_;
    };
    result 'url','title','content', 'writer_say' ;
};
my ($f) = @_;
return unless($f=~/\.zip$/);
print "read zip info : $f\n";
my $zip = Archive::Zip->new($f);

my @members = $zip->membersMatching( '.*\.html' );
@members = sort { $a->fileName() cmp $b->fileName() } @members;
return unless($members[0]->fileName() eq '000.html');

my $res = $INDEX_SCRAPER->scrape(decode('utf8', $members[0]->contents())); 
return unless($res->{site});
if($res->{site}=~/Jjwxc|9Jjz/){
    my @times = sort { $a cmp $b } map { $_->{time} } @{ $res->{chapter_info}};
    $res->{time} = $times[-1];
}else{
    $res = $INDEX_SCRAPER_YQ->scrape(decode('utf8', $members[0]->contents())); 
    $res->{chapter_num} = scalar(@{ $res->{chapter_info} });
    return unless($res->{chapter_num}>0);
    delete $res->{time} if(defined $res->{time} and($res->{time}!~/\d+-\d+-\d+/ or $res->{time}=~/\d+-\d+-00/));
}
shift(@members);

for my $m (@members){
    print "\rread : ",$m->fileName();
    my ($id) = $m->fileName()=~/0*(\d+)/;
    my $r = $res->{chapter_info}[$id-1];
    my $html  = decode('utf8', $m->contents());
    my $chap_res = $CHAPTER_SCRAPER->scrape($html);
    my @keys = ( 'url', 'content','writer_say'
#, 'title' 
    );
    @{ $r }{@keys} = @{$chap_res}{@keys};
}

return $res;
}

sub read_info_from_html {
    my ($f) = @_;
    return unless($f=~/\.html$/);
    (my $txt_file = $f)=~s/.html$/.txt/;
    print "\r生成电子书：", decode($LOCALE, "$f -> $txt_file"), "\n";
    my $html = decode('utf8', slurp($f));
    my %info;
    @info{ 'writer','name'} = $html=~m{<title>\s*(.*\S)\s*《(.*)》\s*</title>}s;
    $html=~s#</body>.*##gs;
    if($html=~m#<div class="floor">#s){
        my @chap = split '<div class="floor">' , $html;
        if($#chap){
            $info{chapter_num} = $#chap;
            for my $i (1..$#chap){
                my %chap_info;
                $chap_info{'id'}=$i;
                $chap_info{'type'}='normal';
                @chap_info{'title','content'}= $chap[$i]=~m#"toc\d+">(.*?)</a></div>\s*<div class="flcontent">(.*)</div>\s*</div>\s*$#sg;
                push @{$info{chapter_info}}, \%chap_info;
        }
    }
    }else{

        my @chap = split '<h1><a name=' , $html;
        if($#chap){
            $info{chapter_num} = $#chap;
            for my $i (1..$#chap){
                my %chap_info;
                $chap_info{'id'}=$i;
                $chap_info{'type'}='normal';
                @chap_info{'title','content'}= $chap[$i]=~m#"toc\d+">(.*?)</a></h1>(.*)#sg;
                push @{$info{chapter_info}}, \%chap_info;
        }
    }else{
        $info{chapter_num} = 1;
        my %chap_info;
        $chap_info{'id'}=1;
        $chap_info{'type'}='normal';
        $chap_info{'title'}=$info{'name'};
        ($chap_info{'content'}) = $html=~m#</h1>(.*?)$#sg;
        push @{$info{chapter_info}}, \%chap_info;
    #print Dumper(%info);exit;
    }
    }
    return \%info;
}
