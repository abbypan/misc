#!/usr/bin/perl 
use strict;
use warnings;

use Mail::Outlook;
use Win32::OLE::Const 'Microsoft Outlook';
use Date::Calc qw/Today Delta_Days/;
use Getopt::Std;
$| = 1;
our $DEFAULT_DAYS_THRESOLD = 21;    # Ĭ��ɾ��21��ǰ���ʼ�
our @DEFAULT_FROM_EMAIL = qw/SOMEGRP someuser@xxx.com/;    #Ĭ�ϼ����ʼ�������

our %OPTION;
getopt( 'mftbd', \%OPTION );
$OPTION{d} ||= $DEFAULT_DAYS_THRESOLD;
$OPTION{f} =
  exists $OPTION{f} ? [ split ',', $OPTION{f} ] : \@DEFAULT_FROM_EMAIL;
$OPTION{f} = map { $_ => 1 } @{ $OPTION{f} };
@OPTION{qw/year month day/} = Today();

die <<'__USAGE__'
DESC  : ָ������ɾ��outlook�ʼ�
USAGE : perl delete_outlook_mail.pl [����]
EXAMPLE : perl delete_outlook_mail.pl -m "somemailbox/miscfolder/log" -f "abc@xxx.com" -t "some log" -b "all ok" -D 

����˵����
-m �ʼ���·��������"somemailbox/miscfolder"��somemailboxΪ��������miscfolder/logΪ�������ʼ���
-f �����ˣ�����"abc@xxx.com"��Ҳ����ָ����������� "SOMEGRP,someuser@xxx.com"
-t �ʼ����⣬���� "some log"
-b �ʼ����ģ�����"all ok"
-d �ʼ�����ʱ����������ж����죬Ĭ��Ϊ21��
-D �����ʼ�����ʱ����ʲôʱ������ָ��������ɾ��(����-d����)
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
        print "ɾ�� $folder...\n";
        delete_mail_folder( $folder, $opt );

        print "\n\n����ɾ�� $trash_folder...\n";
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
    my $trash_folder = $namespace->Folders( $path[0] )->Folders('��ɾ���ʼ�');
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

    #δָ���κ�ƥ����������Ĭ��ɾ��
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
