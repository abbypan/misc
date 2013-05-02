#===============================================================================
#  DESCRIPTION:  小说打包成zip的模块
#       AUTHOR:  AbbyPan (USTC), <abbypan@gmail.com>
#===============================================================================
package Novel::Packer::Zip;
use strict;
use warnings;
use utf8;
use Moo;
extends 'Novel::Packer::Base';

use Encode;
use Archive::Zip qw/:ERROR_CODES/;

has '+book_name_suffix' => ( default => sub {'zip'} );

sub extract_book_info {
    my ( $self, $file ) = @_;

    my $zip = Archive::Zip->new($file);
    return unless ( defined $zip );

    $_ = $zip->contents('000.html');
    return unless ( defined $_ );

    my $html = decode( 'utf-8', $_ );
    my $info = $self->extract_index_info( \$html );

    return $info;
} ## end sub extract_book_info

sub pack_book {
    my ( $self, $data_dir, $bookname ) = @_;

    my $zip = Archive::Zip->new();

    $zip->addTree($data_dir);

    $zip->writeToFileNamed($bookname);
} ## end sub pack_book

sub pack_update_book {
    my ( $self, $file, $data_dir, $del_chaps ) = @_;

    my $zip = Archive::Zip->new($file);

    $zip->updateTree($data_dir);

    for my $i (@$del_chaps) {
        my $html = sprintf( '%03d.html', $i );
        $zip->removeMember($html);
    }

    $zip->overwrite($file);
} ## end sub pack_update_book

no Moo;
1;
