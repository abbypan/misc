#===============================================================================
#  DESCRIPTION:  小说下载、更新引擎
#       AUTHOR:  AbbyPan (USTC), <abbypan@gmail.com>
#===============================================================================
package Novel::Agent;
use strict;
use warnings;
use utf8;
use Moo;

use Cwd;
use Encode qw/encode decode/;
use File::Spec;
use File::Temp qw/tempdir/;
use Parallel::ForkManager;
use Term::Menus;
use Term::ProgressBar;

use Novel::Browser;
use Novel::Template;
use Novel::Parser::Jjwxc;
use Novel::Parser::Dddbbb;
use Novel::Packer::Zip;

has locale => (
    is      => 'rw',
    default => sub { $^O ne 'MSWin32' ? 'utf-8' : 'cp936' },
);

has parallel => (
    is      => 'rw',
    default => sub {8},
);

#小说下载选单
has select => (
    is      => 'rw',
    default => sub {1},
);

#递归处理文件夹?按系列建小说目录?
has recur => (
    is      => 'rw',
    default => sub {1},
);

has browser => ( is => 'rw', );

has parser => (
    is      => 'rw',
    default => sub {
        my ($self) = @_;
        my $parser = new Novel::Parser::Jjwxc();
        return $parser;
    },
);

has packer => (
    is      => 'rw',
    default => sub {
        my ($self) = @_;
        my $packer = new Novel::Packer::Zip();
        return $packer;
    },
);

has template => (
    is      => 'rw',
    default => sub {
        my ($self) = @_;
        my $template = new Novel::Template();
        return $template;
    },
);

sub set_browser {
    my ( $self, %opt ) = @_;
    $self->{browser} = new Novel::Browser(%opt);
}

sub set_parser {
    my ( $self, $site ) = @_;
    $self->{parser} = eval qq[new Novel::Parser::$site()];
}

sub set_packer {
    my ( $self, $pack_type, %opt ) = @_;

    $self->{packer} = eval qq[new Novel::Packer::$pack_type()];
    for ( keys(%opt) ) {
        next unless ( $opt{$_} );
        $self->{packer}{$_} = $opt{$_};
    }
} ## end sub set_packer

sub set_template {
    my ( $self, %opt ) = @_;
    $self->{template} = new Novel::Template(%opt);
}

############# {{{ get_book

sub get_book {
    my ( $self, @args ) = @_;

    my $index_ref = $self->get_index_ref(@args);
    return unless ( defined $index_ref and exists $index_ref->{book} );

    my $file = $self->{packer}->generate_bookname($index_ref);
    return unless ( defined $file );

    $self->print_book_info($index_ref);
    my @chapter_list = ( 1 .. $index_ref->{chapter_num} );

    my $temp_dir = $self->get_book_chapters( $index_ref, \@chapter_list );
    $self->{packer}->pack_book( $temp_dir, $file );

    #rmtree($temp_dir);

    return $file;
} ## end sub get_book

sub get_index {
    my ( $self, @args ) = @_;

    my $index_ref = $self->get_index_ref(@args);
    return unless ( exists $index_ref->{book} );

    $self->generate_index_html($index_ref);

    return $index_ref;
} ## end sub get_index

sub get_index_ref {

    my ( $self, @args ) = @_;
    my ($index_url) = $self->{parser}->generate_index_url(@args);

    my $html_ref = $self->{browser}->get_url_ref($index_url);

    $self->{parser}->alter_index_before_parse($html_ref);
    my $ref = $self->{parser}->parse_index($html_ref);
    return unless ( defined $ref );

    $ref->{index_url} = $index_url;
    $ref->{site}      = $self->{parser}{site};

    return $ref unless ( exists $ref->{book_info_urls} );

    while ( my ( $url, $info_sub ) = each %{ $ref->{book_info_urls} } ) {
        my $info = $self->{browser}->get_url_ref($url);
        next unless ( defined $info );
        $info_sub->( $ref, $info );
    }

    return $ref;
} ## end sub get_index_ref

sub print_book_info {
    my ( $self, $index_ref, $add, $del ) = @_;

    my ( $book, $writer, $progress, $chapter_num ) =
        @$index_ref{qw/book writer progress chapter_num/};
    my $add_chap_num = ref($add) eq 'ARRAY' ? ( $#{$add} + 1 ) : 0;
    my $del_chap_num = ref($del) eq 'ARRAY' ? ( $#{$del} + 1 ) : 0;

    return unless ( defined $book );
    $book .= '(' . $progress . ')'
        if ( defined $progress );

    my $out = pack( "A28A14", $book, $writer );

    $out .=
        $chapter_num
        ? "共[$chapter_num]章！"
        : "锁文了！";
    $out .= "删除[$del_chap_num]章！"
        if ($del_chap_num);
    $out .= "更新[$add_chap_num]章！"
        if ($add_chap_num);
    $out .= "没更新！"
        unless ( $add_chap_num or $del_chap_num );

    print "\r", encode( $self->{locale}, $out ), "\n";
} ## end sub print_book_info

sub get_book_chapters {
    my ( $self, $index_ref, $add_chaps ) = @_;

    my ( $home, $temp ) = $self->make_temp_dir( $index_ref->{index_url} );

    chdir $temp;

    $self->{template}->generate_index_html($index_ref);

    $self->get_chapters( $index_ref, $add_chaps ) if (@$add_chaps);

    chdir $home;

    return $temp;
} ## end sub get_book_chapters

######### }}}

######## {{{ get_book_chapters

sub make_temp_dir {

    my ( $self, $arg ) = @_;

    my $home = Cwd::getcwd();

    my ($id) = $arg =~ /.*([\d\w]+)/;

    my $temp = tempdir( "/novel_$self->{parser}{site}_${id}_XXXXXXXX", TMPDIR => 1, CLEANUP => 1 );

    return ( $home, $temp );
} ## end sub make_temp_dir

sub get_chapters {

    my ( $self, $index_ref, $ids_ref ) = @_;

    my $i = 0;

    my $count = scalar(@$ids_ref);
    my $progress = Term::ProgressBar->new( { count => $count } );

    my $pm = new Parallel::ForkManager( $self->{parallel} );
    $pm->run_on_finish(
        sub {
            ++$i;
            $progress->update($i);
        }
    );

    for my $id (@$ids_ref) {
        $pm->start and next;
        my $url = $index_ref->{chapter_urls}->[$id];

        if ( defined $url ) {
            for ( 1 .. 2 ) {
                my $f = $self->get_chapter( $url, $id );
                last if ( -f $f );
            }
        } ## end if ( defined $url )
        else {
            $self->gen_empty_chapter($id);
        }

        $pm->finish;
    } ## end for my $id (@$ids_ref)
    $pm->wait_all_children;
    return;
} ## end sub get_chapters

####### }}}

###### {{{ get_chapters

sub get_chapter {
    my ( $self, @args ) = @_;

    my $ref = $self->get_chapter_ref(@args);
    return unless ( exists $ref->{chapter} );

    my $file = $self->{template}->generate_chapter_html($ref);

    return $file;
} ## end sub get_chapter

sub gen_empty_chapter {
    my ( $self, $id ) = @_;

    my $data = $self->get_empty_chapter_ref($id);

    my $file = $self->{template}->generate_empty_chapter_html($data);

    return $file;
} ## end sub gen_empty_chapter

sub get_chapter_ref {
    my ( $self, @args ) = @_;

    my ( $chap_url, $chap_id ) = $self->{parser}->generate_chapter_url(@args);
    my $html_ref = $self->{browser}->get_url_ref($chap_url);
    return unless ($html_ref);

    $self->{parser}->alter_chapter_before_parse($html_ref);
    my $ref = $self->{parser}->parse_chapter($html_ref);
    return unless ($ref);

    $ref->{content} =~ s#\s*([^><]+)(<br />\s*){1,}#<p>$1</p>\n#g;
    $ref->{content} =~ s#(\S+)$#<p>$1</p>#s;
    $ref->{content} =~ s###g;

    $ref->{chapter_url} = $chap_url;
    $ref->{chapter_id}  = $chap_id;

    return $ref;
} ## end sub get_chapter_ref

sub get_empty_chapter_ref {
    my ( $self, $id ) = @_;

    my %data;
    $data{chapter_id} = $id;

    return \%data;
} ## end sub get_empty_chapter_ref

###### }}}

##### {{{  update_book

sub update_book {
    my ( $self, $file, $must_update_chaps ) = @_;
    print encode( $self->{locale}, "\r检查更新 : " ), $file;

    my ($ref) = $self->{packer}->extract_book_info($file);
    return unless ( $ref->{site} );

    $self->set_parser( $ref->{site} );

    my $new_index_ref = $self->get_index_ref( $ref->{index_url} );
    unless ( exists $new_index_ref->{chapter_info} ) {
        my $error_info = pack( "A28A14", $ref->{book}, $ref->{writer} );
        print encode( $self->{locale}, " $error_info 更新失败！" );
        return;
    }

    #确定更新的章节，并更新目录信息
    my ( $add_chaps, $del_chaps ) =
        $self->check_update_chapters( $ref, $new_index_ref, $must_update_chaps );

    $self->print_book_info( $new_index_ref, $add_chaps, $del_chaps );

    #没更新
    return
        unless ( defined $add_chaps and ref($add_chaps) eq 'ARRAY' );

    my $temp_dir = $self->get_book_chapters( $new_index_ref, $add_chaps );

    $self->{packer}->pack_update_book( $file, $temp_dir, $del_chaps );

    return 1;
} ## end sub update_book

sub check_update_chapters {

    #检查小说是否有章节更新
    my ( $self, $update_time_ref, $new_index_ref, $must_update_chaps ) = @_;

    my ( $add_chap_ref, $del_chap_ref );

    my $new_chap_num = $new_index_ref->{chapter_num};

    #目前锁文了
    return ( [], [] ) unless ($new_chap_num);

    my $old_chap_num = $update_time_ref->{chapter_num};

    #原来文是锁上的
    return ( [ 1 .. $new_chap_num ], [] ) unless ($old_chap_num);

    my $new_chaps_info = $new_index_ref->{chapter_info};
    return ( [], [] ) unless ($new_chaps_info);

    #进行比较的最大章节数
    my $compare_num = $old_chap_num;

    if ( $new_chap_num < $old_chap_num ) {

        @$del_chap_ref = ( $new_chap_num + 1 .. $old_chap_num );
        $compare_num   = $new_chap_num;
    }
    elsif ( $new_chap_num > $old_chap_num ) {

        @$add_chap_ref = ( $old_chap_num + 1 .. $new_chap_num );
    }

    #开始比较
    if ( exists $update_time_ref->{chapter_info} ) {
        for my $i ( 1 .. $compare_num ) {
            my $old = $update_time_ref->{chapter_info}->[ $i - 1 ];

            my $new = $new_chaps_info->[ $i - 1 ];

            #要求有更新时间
            next
                unless ( ( defined $new->{time} )
                and ( defined $old->{time} ) );

            #现在章节的状况
            if ( $new->{type} ne 'normal' ) {

                #现在章节锁了，继承章节原来的信息
                #防止  未锁->锁->开锁  导致重新下载的情况
                $new->{type} = $old->{type};
                $new->{time} = $old->{time};
            } ## end if ( $new->{type} ne 'normal')
            else {

                #现在章节没锁，且符合以下任一条件，则更新
                push @$add_chap_ref, $i
                    if (
                    ( $old->{type} ne 'normal' )           #如果原来章节锁了
                    or ( $old->{time} ne $new->{time} )    #如果更新时间变了
                    or ( $must_update_chaps
                        and ( $i ~~ @$must_update_chaps ) )    #指定必须更新
                    );
            } ## end else [ if ( $new->{type} ne 'normal')]
        }    #for
    }    #if

    return ( $add_chap_ref, $del_chap_ref );
} ## end sub check_update_chapters

#}}}

##### {{{  rename_book

sub rename_book {
    my ( $self, $file, $format ) = @_;
    return unless ( -f $file );

    my ( $volume, $dir, $basename ) = File::Spec->splitpath($file);
    ( my $target_dir = $file ) =~ s/$basename$//;

    my ($info) = $self->{packer}->extract_book_info($file);
    return unless ( defined $info );

    my $new_file = $self->{packer}->generate_bookname( $info, $format, $target_dir );
    return unless ($new_file);

    rename( $file, $new_file );
} ## end sub rename_book

##### }}}

##### {{{  get_writer

sub get_writer {
    my ( $self, @args ) = @_;

    my ($writer_ref) = $self->get_writer_ref(@args);

    my $writer_dir = $self->make_locale_dir( $writer_ref->{writer} );
    chdir($writer_dir);

    my $select_ref = $self->select_book( $writer_ref->{writer}, $writer_ref->{series} );

    $self->get_books($select_ref);

    chdir File::Spec->updir;

    return;
} ## end sub get_writer

sub get_writer_ref {
    my ( $self, @args ) = @_;

    my ($writer_url) = $self->{parser}->generate_writer_url(@args);

    my $html_ref = $self->{browser}->get_url_ref($writer_url);

    my $writer_books = $self->{parser}->parse_writer($html_ref);

    return $writer_books;
} ## end sub get_writer_ref

sub make_locale_dir {
    my ( $self, $name ) = @_;
    $name =~ s/[[:punct:]]*//g;
    my $dir = encode( $self->{locale}, $name );
    mkdir $dir unless ( -d $dir );
    return $dir;
} ## end sub make_locale_dir

sub select_book {

    my ( $self, $banner, $info_ref ) = @_;

    return $info_ref unless ( $self->{select} );

    $banner = encode( $self->{locale}, $banner );
    my %menu = ( 'Select' => 'Many', 'Banner' => $banner, );

    #菜单项，不搞层次了，恩
    my %select;
    my $i = 1;
    for my $r (@$info_ref) {
        my ( $info, $key, $url ) = @$r;
        my $item = "$info --- $key";
        $select{$item} = $url;
        $item = encode( $self->{locale}, $item );
        $menu{"Item_$i"} = { Text => $item };
        $i++;
    } ## end for my $r (@$info_ref)

    #最后选出来的小说
    my @select_result;
    for my $item ( &Menu( \%menu ) ) {
        $item = decode( $self->{locale}, $item );
        my ( $info, $key ) = ( $item =~ /^(.*) --- (.*)$/ );
        push @select_result, [ $info, $key, $select{$item} ];
    }

    return \@select_result;

} ## end sub select_book

sub get_books {
    my ( $self, $info_ref ) = @_;

    unless ( $self->{recur} ) {
        $self->get_book( $_->[2] ) for @$info_ref;
        return;
    }

    for my $r (@$info_ref) {
        my ( $info, $key, $url ) = @$r;
        my $series_dir = $self->make_locale_dir($info);

        chdir($series_dir);
        $self->get_book($url);
        chdir File::Spec->updir;

    } ## end for my $r (@$info_ref)
    return;
} ## end sub get_books

##### }}}

#### {{{ query

sub query {
    my ( $self, $type, $keyword ) = @_;

    my $result = $self->get_query_ref( $type, $keyword );

    my $select_ref = $self->select_book( "查询 $type : $keyword", $result );

    $self->get_books($select_ref);

} ## end sub query

sub get_query_ref {
    my ( $self, $type, $keyword ) = @_;

    my $key = encode( $self->{parser}->charset, $keyword );
    my ( $url, $post_vars ) = $self->{parser}->make_query_url( $type, $key );
    my $html_ref = $self->{browser}->get_url_ref( $url, $post_vars );
    return unless $html_ref;

    my $result          = $self->{parser}->parse_query($html_ref);
    my $result_urls_ref = $self->{parser}->get_query_result_urls($html_ref);
    return $result unless ( defined $result_urls_ref );

    for my $url (@$result_urls_ref) {
        my $h = $self->{browser}->get_url_ref($url);
        my $r = $self->{parser}->parse_query($h);
        push @$result, @$r;
    }

    return $result;
} ## end sub get_query_ref

### }}}

no Moo;
1;
