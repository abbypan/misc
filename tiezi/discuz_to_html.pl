#!/usr/bin/perl 
use Data::Dumper;
use SimpleDBI;
use Encode;
use Encode::Locale;
use POSIX qw/strftime/;
use Novel::Robot::Packer;
use utf8;

### config {{{
my $prefix   = 'pre';
my $main_dir = 'gym';
my $dbi      = SimpleDBI->new(
    type   => 'mysql',
    host   => 'localhost',
    usr    => 'someusr',
    passwd => 'somepwd',
    db     => 'somedb',
    port   => 3306,
);
###}}}

my $packer = Novel::Robot::Packer->new( type => 'html' );
my $forum =
  $dbi->query_db(qq[select fid,name from ${prefix}_forum_forum where threads>0]);
for my $fr (@$forum) {
    my ( $fid, $fname ) = @$fr;
    $fname =~ s/[[:punct:]]//sg;
    my $fdir = "$main_dir/$fid.$fname";
    mkdir( encode( locale => $fdir ) );

    my $thread = $dbi->query_db(
        qq[select tid,author,subject from ${prefix}_forum_thread where fid=$fid]
    );
    for my $tr (@$thread) {
        my ( $tid, $author, $subject ) = @$tr;
        $author =~ s/[[:punct:]]//sg;
        $subject =~ s/[[:punct:]]//sg;
        my $tfile = encode( locale => "$fdir/$tid.$author.$subject.html" );

        my $post = $dbi->query_db(
            qq[select author,dateline,message 
            from ${prefix}_forum_post 
            where tid=$tid and fid=$fid 
            order by dateline]
        );
        my $i          = 0;
        my @floor_list = map {
            my $c = $_->[2];
            $c =~ s/\[/</sg;
            $c =~ s/\]/>/sg;
            {
                writer => $_->[0],
                time   => strftime( "%Y-%m-%d %H:%M:%S", localtime( $_->[1] ) ),
                content => $c,
                id      => $i++,
                title   => '',
            }
        } @$post;

        my %tdata = (
            writer     => $author,
            book       => $subject,
            floor_list => \@floor_list,
        );
        print $tfile, "\n";
        $packer->main( \%tdata, output => $tfile, with_toc => 1 );

    }
}
