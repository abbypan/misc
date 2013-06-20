#!/usr/bin/perl 
use strict;
use warnings;

use Mail::Outlook;
use Win32::OLE::Const 'Microsoft Outlook';
$| = 1;

my ( $s_path, $d_path ) = @ARGV;

die <<__USAGE__
DESC    :  移动OUTLOOK邮件
USAGE   :  perl move_outlook_mail.pl [源邮件路径] [目标邮件路径]
EXAMPLE :  perl move_outlook_mail.pl srcmailbox/工作  dstmailbox/存档 
__USAGE__
  unless ($d_path);

main_move_outlook_mail( $s_path, $d_path );

sub main_move_outlook_mail {
    my ( $s_path, $d_path ) = @_;

    my $outlook   = Win32::OLE->new('Outlook.Application');
    my $namespace = $outlook->GetNamespace("MAPI");

    my $s_folder = get_mail_folder( $namespace, $s_path );
    my $d_folder = get_mail_folder( $namespace, $d_path );

    while (1) {
        my $c = move_mail_folder( $s_folder, $d_folder );
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

sub move_mail_folder {
    my ( $s_folder, $d_folder ) = @_;

    my $items     = $s_folder->Items;
    my $all_count = $items->Count;
    return unless ($all_count);

    for ( my $i = 1 ; $i <= $all_count ; $i++ ) {
        my $msg = $items->item($i);
        next unless ($msg);
        print "\r $i/$all_count move : ", $msg->{Subject};
        $msg->Move($d_folder);
    }
    return $all_count;
}
