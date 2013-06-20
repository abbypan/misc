package ReadNovel;
use Dancer ':syntax';
use Encode;
use Template;
use Dancer::Plugin::Database;
use Data::Dumper;

use DBI;
use Encode;
use utf8;

our $VERSION = '0.1';
our %QUERY_KEY_CHS = (
    'type'=>'类型',
    'series'=>'系列',
    'writer_name'=>'作者名',
    'writer'=> '作者号',
    'tag'=>'标签',
    'book_name'=>'书名',
);
our @QUERY_KEY_LIST = map { { 'k'=>$_, 'v'=>$QUERY_KEY_CHS{$_} } } sort keys(%QUERY_KEY_CHS);


our $TT = Template->new(
    START_TAG => quotemeta('<%'),
    END_TAG   => quotemeta('%>'),
);

get '/' => sub {
        redirect "/writerlist";
};


get '/writerlist' => sub {
        my $sql = qq[
            select writer.id as id ,writer.name as name,count(*) as count,writer.comment           as comment 
            from writer,book
            where
                book.writer_id = writer.id
                group by writer.id, writer.name,writer.comment
                order by 3 desc
        ];
        my $info = database->selectall_arrayref(
            $sql,
            { Slice => {} },
        );
        for my $r (@$info){
    while ( my ( $k, $v ) = each %$r ) {
        $r->{$k} = decode( 'utf8', $v );
    } ## end while ( my ( $k, $v ) = each...)
}
        template 'writerlist', { 
            'title' => "作者列表", 'writerlist'=> $info ,
            typelist => \@QUERY_KEY_LIST, 
 };

};

post '/booklist' => sub {
        #my $key = encode_utf8(params->{key});
        #my $value = encode_utf8(params->{value});
        my $key = params->{key};
        my $value =  params->{value};
        redirect "/booklist/$key/$value";
};

get '/booklist' => sub {
    my $limit = 20;
        my $sql = qq[
            select distinct book.name,book.id,writer.name as writer,book.writer_id,book.series,book.type,book.time
            from book,writer
            where
                book.writer_id = writer.id
                    order by book.time desc
                limit $limit;
        ];
        my $info = database->selectall_arrayref(
            $sql,
            { Slice => {} },
        );
        for my $r (@$info){
    while ( my ( $k, $v ) = each %$r ) {
        $r->{$k} = decode( 'utf8', $v );
    } ## end while ( my ( $k, $v ) = each...)
}
        template 'booklist', { 'title' => "小说列表(未指定则列出前 $limit 本)", 'booklist'=> $info ,
            typelist => \@QUERY_KEY_LIST };

};

get '/booklist/:key/:value' => sub {
        #my $key = encode('utf8',params->{key});
        #my $value = encode('utf8', params->{value});
        my $key = params->{key};
        my $value = params->{value};
        redirect '/booklist' unless($value);
        my $title = qq[按"$QUERY_KEY_CHS{$key}"查书,关键字为"$value"];
        redirect '/booklist' unless($key=~/^writer|series|type|tag|writer_name|book_name$/);
        $key=~s/writer\b/writer.id =/;
        $key=~s/writer_name/writer.name ~/;
        $key=~s/book_name/book.name ~/;
        $key=~s/(series|type)/book.$1 ~/;
        if($key=~/series/){
            $value=~s/(?<=\S)\s+\S+$//;
            $value=~s/(?<=\D)(NO\.)?\d+$//;
        }

        my $sql = qq[
            select distinct book.name,book.id,writer.name as writer,book.writer_id,book.series,book.type,book.time
            from book,writer
            where
                book.writer_id = writer.id
        ];
        if($key ne 'tag'){
            $sql.=" and $key ? ";
        }else{
            $sql.=qq[
                and book.id in (select distinct book_id from book_tag where
                    tag ~ ? )
            ]; 
        }
        $sql.=" order by book.series";

        my $info = database->selectall_arrayref(
            $sql,
            { Slice => {} },
            $value
        );
        for my $r (@$info){
    while ( my ( $k, $v ) = each %$r ) {
        $r->{$k} = decode( 'utf8', $v );
    } ## end while ( my ( $k, $v ) = each...)
}
        template 'booklist', { 'title' => $title, 'booklist'=> $info ,
            typelist => \@QUERY_KEY_LIST };
    };

get '/chapter/:book_id/:id' => sub {
    my $book_id      = params->{book_id};
    my $id           = params->{id};
    my $chapter_info = database->selectrow_hashref(
        'select * from chapter where book_id = ? and id= ?',
        undef, $book_id, $id );

    my $info = database->selectrow_hashref(
        'select writer.name as writer, book.name 
            as book, book.chapter_num
            from writer,book where book.id= ? and writer.id=book.writer_id',
        undef, $book_id );
    $chapter_info->{writer} = $info->{writer};
    $chapter_info->{book}   = $info->{book};
    $chapter_info->{home}   = "/book/$book_id";
    $chapter_info->{prev_chap} =
        $id > 1
        ? "/chapter/$book_id/" . ( $id - 1 )
        : $chapter_info->{home};
    $chapter_info->{next_chap} =
        $id < $info->{chapter_num}
        ? "/chapter/$book_id/" . ( $id + 1 )
        : $chapter_info->{home};
    while ( my ( $k, $v ) = each %$chapter_info ) {
        $chapter_info->{$k} = decode( 'utf8', $v );
    } ## end while ( my ( $k, $v ) = each...)

    template 'chapter.tt', $chapter_info;
};

get '/book/:id' => sub {
    my $book_id = params->{id};

    my $book_info =
        database->selectrow_hashref( 'select * from book where id = ?',
        undef, $book_id );

    my $writer_name =
        database->selectrow_hashref( 'select name from writer where id = ?',
        undef, $book_info->{writer_id} );
    $book_info->{writer} = $writer_name->{name};

    while ( my ( $k, $v ) = each %$book_info ) {
        $book_info->{$k} = decode( 'utf8', $v );
    } ## end while ( my ( $k, $v ) = each...)

    my $chapter_info = database->selectall_arrayref(
        "select id,title,volume,time from chapter where book_id =
              ? order by id",
        { Slice => {} },
        $book_id

    );
    for my $chap (@$chapter_info) {
        $chap->{url} = "/chapter/$book_id/$chap->{id}";
        while ( my ( $k, $v ) = each %$chap ) {
            $chap->{$k} = decode( 'utf8', $v );
        } ## end while ( my ( $k, $v ) = each...)

    } ## end for my $chap (@$chapter_info)

    my $tag = database->selectall_arrayref(
        "select tag from book_tag where book_id = ?",
        undef, $book_id );
    my $tag_info = join ", ",
        map { qq#<a href="/booklist/tag/$_->[0]">$_->[0]</a># } @$tag;
    $book_info->{tag} = decode( 'utf8', $tag_info );

    $book_info->{type} = $book_info->{type}?
        qq#<a href="/booklist/type/$book_info->{type}">$book_info->{type}</a>#
        : ''
        ;
    $book_info->{series} =
       $book_info->{series}?
        qq#<a href="/booklist/series/$book_info->{series}">$book_info->{series}</a>#
        : ''
        ;
    $book_info->{writer_url} = qq#/booklist/writer/$book_info->{writer_id}#;

    $book_info->{chapter_info} = $chapter_info;

    template 'book.tt', $book_info;
};

true;

