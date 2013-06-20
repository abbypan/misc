#!/usr/bin/perl 
use strict;
use warnings;

use Mail::Outlook;
use Win32::OLE::Const 'Microsoft Outlook';
use Date::Calc qw/Today Delta_Days/;
use Getopt::Std;
$| = 1;
our $DEFAULT_DAYS_THRESOLD = 21;    # 默认删除21天前的邮件
our @DEFAULT_FROM_EMAIL = qw/SOMEGRP someuser@xxx.com/;    #默认检查的邮件发件人

our %OPTION;
getopt( 'mftbd', \%OPTION );
$OPTION{d} ||= $DEFAULT_DAYS_THRESOLD;
$OPTION{f} =
  exists $OPTION{f} ? [ split ',', $OPTION{f} ] : \@DEFAULT_FROM_EMAIL;
$OPTION{f} = map { $_ => 1 } @{ $OPTION{f} };
@OPTION{qw/year month day/} = Today();

die <<'__USAGE__'
DESC  : 指定条件删除outlook邮件
USAGE : perl delete_outlook_mail.pl [参数]
EXAMPLE : perl delete_outlook_mail.pl -m "somemailbox/miscfolder/log" -f "abc@xxx.com" -t "some log" -b "all ok" -D 

参数说明：
-m 邮件夹路径，例如"somemailbox/miscfolder"，somemailbox为邮箱名，miscfolder/log为二层子邮件夹
-f 发件人，例如"abc@xxx.com"，也可以指定多个，例如 "SOMEGRP,someuser@xxx.com"
-t 邮件标题，例如 "some log"
-b 邮件正文，例如"all ok"
-d 邮件发送时间距离现在有多少天，默认为21天
-D 不管邮件发送时间是什么时候，满足指定条件就删除(覆盖-d参数)
__USAGE__
  unless ( $OPTION{m} );

main_delete_outlook_mail( \%OPTION );

sub main_delete_outlook_mail {
    my ($opt) = @_;

    my $outlook   = Win32::OLE->new('Outlook.Application');
    my $namespace = $outlook->GetNamespace("MAPI");

    my $folder = get_mail_folder( $namespace, $opt->{m} );
    my $trash_folder = get_trash_folder( $namespace, $opt->{m} );

    while (1) {
        print "删除 $folder...\n";
        delete_mail_folder( $folder, $opt );

        print "\n\n彻底删除 $trash_folder...\n";
        my $c = delete_mail_folder($trash_folder);

        return unless ($c);
    }
}

sub get_mail_folder {
    my ( $namespace, $path_str ) = @_;
    my @path = split '/', $path_str;
    my $folder;
    my $cmd = '$folder = $namespace';
    $cmd .= qq{->Folders('$_')} for @path;
    eval $cmd;
    return $folder;
}

sub get_trash_folder {
    my ( $namespace, $path_str ) = @_;
    my @path = split '/', $path_str;
    my $trash_folder = $namespace->Folders( $path[0] )->Folders('已删除邮件');
    return $trash_folder;
}

sub delete_mail_folder {
    my ( $folder, $opt ) = @_;

    my $items     = $folder->Items;
    my $all_count = $items->Count;
    return unless ( defined $all_count );

    my $all_delete_count = 0;
    for ( my $i = 1 ; $i <= $all_count ; $i++ ) {
        my $msg = $items->item($i);
        next unless ($msg);

        print "\r$i/$all_count : ";
        next unless ( delete_mail( $msg, $opt ) );

        $all_delete_count++;
    }

    return $all_delete_count;
}

sub delete_mail {
    my ( $msg, $opt ) = @_;

    #未指定任何匹配条件，则默认删除
    return 1 unless ($opt);

    my $email = $msg->{SenderName} || '';
    return unless ( $email and exists $opt->{f}{$email} );

    unless ( exists $opt->{D} ) {
        return unless ( check_mail_date_to_delete( $msg, $opt ) );
    }

    my $subject = $msg->{Subject};
    return unless ( exists $opt->{t} and $subject =~ /$opt->{t}/o );

    return unless ( exists $opt->{b} and $msg->{Body} =~ /$opt->{b}/o );

    print "delete! $email, $subject";

    $msg->Delete();

    return 1;
}

sub check_mail_date_to_delete {
    my ( $msg, $opt ) = @_;
    my $date = $msg->ReceivedTime()->Date();
    my ( $s_year, $s_month, $s_day ) = split '-', $date;
    my $delta_days = Delta_Days( $s_year, $s_month, $s_day,
        $opt->{year}, $opt->{month}, $opt->{day} );

    return if ( $delta_days < $opt->{d} );
    return 1;
}
