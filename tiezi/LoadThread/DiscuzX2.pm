package LoadThread::DiscuzX2;
use parent 'Teng';

use LoadThread::SiteConfig;

use Digest::MD5 qw(md5_hex);
use Date::Calc qw(Mktime);
use Encode;

sub read_thread_data {
    my ( $self, $file ) = @_;

    my $html;
    open my $fh, "<:$LoadThread::SiteConfig::FILE_CHARSET", $file;
    {
        local $/ = undef;
        $html = <$fh>;
    }
    close $fh;
    $html = encode( $LoadThread::SiteConfig::CHARSET, $html );

    my ($subject) = $html =~ m#<title>\s*(.+?)\s*</title>#s;
    my @data = $html =~ m#<div class="floor">(.+?)</div>\s+</div>#sg;
    my @floors;
    for (@data) {
        my %temp;
        ( $temp{poster} ) = m#<span class="floor_name">\s*(.+?)\s*</span>#s;
        my ($time) = m#<span class="floor_time">\s*(.+?)\s*</span>#s;
        $temp{dateline} = $self->mktime_from_timestamp("$time:00");
        ( $temp{message} ) = m#<div class="floor_content">\s*(.+)#s;
        $temp{message} =~
          s#<div class="quote">\s*(.+?)</div>#\[quote\]$1\[\/quote\]#sg;
        $temp{message} =~ s#<img\s*src=['"](.+?)['"].*?>#\n$1\n#sg;
        $temp{message} =~ s#<a\s*href=['"](.+?)['"].*?>#\n$1\n#sg;
        $temp{message} =~ s#<[^>]+>##sg;

        $temp{subject} = '';
        push @floors, \%temp;
    }
    $floors[0]{subject} = $subject;
    return \@floors;
}

sub create_member {
    my ( $self, $username ) = @_;

    my $uid = $self->get_uid_by_username($username);
    return $uid if ($uid);

    print "create member : $username\n";

    my $salt = $self->mksalt();
    my $passwd =
      md5_hex( md5_hex($LoadThread::SiteConfig::USER_PASSWD) . $salt );
    my $time = time();
    $self->insert(
        'pre_ucenter_members',
        +{
            username => $username,
            password => $passwd,
            email    => $LoadThread::SiteConfig::USER_EMAIL,
            regip    => $LoadThread::SiteConfig::USER_IP,
            regdate  => $time,
            salt     => $salt,
        }
    );

    $uid = $self->get_uid_by_username($username);
    return unless ($uid);

    $self->insert( 'pre_ucenter_memberfields', +{ uid => $uid, } );

    $self->insert(
        'pre_common_member',
        +{
            uid        => $uid,
            email      => $LoadThread::SiteConfig::USER_EMAIL,
            username   => $username,
            password   => $passwd,
            adminid    => 0,
            groupid    => 10,
            regdate    => $time,
            timeoffset => 9999,
        }
    );

    $self->insert(
        'pre_common_member_count',
        +{
            uid         => $uid,
            extcredits2 => 2,
        }
    );

    return $uid;
}

sub mktime_from_timestamp {
    my ( $self, $t ) = @_;
    my @args = split /[:\- \/]+/, $t;
    return Mktime(@args);
}

sub mksalt {
    my ($self) = @_;
    my @salts = map {
        my $i = int( rand(9999) ) % $#LoadThread::SiteConfig::SALT_CHARS;
        $LoadThread::SiteConfig::SALT_CHARS[$i]
    } ( 1 .. 6 );
    return join( "", @salts );
}

sub get_uid_by_username {
    my ( $self, $username ) = @_;
    my $row =
      $self->single( 'pre_ucenter_members', { username => $username, } );
    return unless ( $row->{row_data} );
    return $row->{row_data}{uid};
}

sub extract_thread_state {
    my ( $self, $f ) = @_;

    my %d;

    my $first = $f->[0];
    $d{author}   = $first->{poster};
    $d{authorid} = $self->create_member( $d{author} );
    $d{subject}  = $first->{subject};
    $d{dateline} = $first->{dateline};

    my $last = $f->[-1];
    $d{lastpost}   = $last->{dateline};
    $d{lastposter} = $last->{poster};

    $d{replies} = $#$f;

    return \%d;
}

sub load_thread_floors {
    my ( $self, $fid, $tid, $f ) = @_;

    my %author_to_id;
    my @floors_data;

    for my $i ( 0 .. $#$f ) {
        my $r      = $f->[$i];
        my $author = $r->{poster};
        $author_to_id{$author} ||= $self->create_member($author);

        my %temp = (
            fid       => $fid,
            tid       => $tid,
            first     => $i > 0 ? 0 : 1,
            author    => $author,
            authorid  => $author_to_id{$author},
            subject   => $r->{subject},
            dateline  => $r->{dateline},
            message   => $r->{message},
            useip     => $LoadThread::SiteConfig::USER_IP,
            htmlon    => 0,
            bbcodeoff => 0,
        );

        $self->insert( 'pre_forum_post', \%temp );
    }
}

sub set_thread_state {
    my ( $self, $fid, $d ) = @_;

    my %data = (
        fid        => $fid,
        author     => $d->{author},
        authorid   => $d->{authorid},
        subject    => $d->{subject},
        dateline   => $d->{dateline},
        lastpost   => $d->{lastpost},
        lastposter => $d->{lastposter},
        replies    => $d->{replies},
    );

    $self->insert( 'pre_forum_thread', \%data );

    my $tid = $self->get_tid( \%data );

    return $tid;
}

sub get_tid {
    my ( $self, $opt ) = @_;
    my $row = $self->single( 'pre_forum_thread', $opt );
    return unless ( $row->{row_data} );
    return $row->{row_data}{tid};
}

sub create_thread {
    my ( $self, $fid, $file ) = @_;

    print "create thread : fid $fid, file $file\n";

    my $f = $self->read_thread_data($file);

    my $state = $self->extract_thread_state($f);
    my $tid = $self->set_thread_state( $fid, $state );
    return unless ($tid);

    $self->load_thread_floors( $fid, $tid, $f );

    return $tid;
}

1;

package LoadThread::DiscuzX2::Schema;
use Teng::Schema::Declare;

#新建贴子
table {
    name 'pre_forum_post';
    columns
      qw( fid tid first author authorid subject dateline message useip htmlon bbcodeoff);
};

table {
    name 'pre_forum_thread';
    columns
      qw(tid fid author authorid subject dateline lastpost lastposter replies);
};

#激活用户
table {
    name 'pre_common_member';
    pk 'uid';
    columns qw(uid email username password adminid groupid regdate timeoffset);
};

table {
    name 'pre_common_member_count';
    pk 'uid';
    columns qw(uid extcredits2);
};

#新建用户
table {
    name 'pre_ucenter_members';
    columns qw(uid username password email regip regdate salt);

    #salt : 6字符随机数[0-9a-z]
    #passwd : md5(md5(raw_passwd).salt)
    #test : hcyy -> salt 043746, regdate 1328622816
};

table {
    name 'pre_ucenter_memberfields';
    pk 'uid';
    columns qw(uid);
};

1;
