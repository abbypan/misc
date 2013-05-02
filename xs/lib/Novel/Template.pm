#===============================================================================
#  DESCRIPTION:  最终生成文件的模板
#       AUTHOR:  AbbyPan (USTC), <abbypan@gmail.com>
#===============================================================================
package Novel::Template;
use strict;
use warnings;
use utf8;

use Encode qw/encode decode/;
use FindBin;
use Text::Xslate;
use File::Slurp qw/slurp/;

use Moo;

has template_dir => (

    #模板文件路径，如果自行指定模板内容则忽略此参数
    is => 'rw',

    default => sub {"$FindBin::RealBin/template"},

);

has target_dir => (

    #默认目标文件路径，如果自行指定文件名则忽略此参数
    is => 'rw',

    default => sub {"."},

);

sub generate_file_from_template {
    my ( $self, $data_ref, $target_file, $source_template ) = @_;

    my $template_content_ref;

    if ( ref($source_template) ) {
        $template_content_ref = \$source_template;
    }
    elsif ( -f $source_template ) {
        my $source_template_content = slurp($source_template);
        $source_template_content = decode( 'utf8', $source_template_content );
        $template_content_ref = \$source_template_content;
    }

    return unless ($template_content_ref);

    my $template = Text::Xslate->new(
        function => {
            format => sub {
                my ($f) = @_;
                return sub {
                    my ($str) = @_;
                    return sprintf( $f, $str );
                    }
            },
        },
        type => 'text',
    );

    my $html = $template->render_string( $$template_content_ref, $data_ref );
    open my $fh, '>:utf8', $target_file;
    print $fh $html;
    close $fh;
    return $self;
} ## end sub generate_file_from_template

sub generate_chapter_html {
    my ( $self, $data_ref, $target_file, $template ) = @_;
    $target_file ||= $self->{target_dir} . "/" . sprintf( "%03d.html", $data_ref->{chapter_id} );
    $template ||= "$self->{template_dir}/chapter.html";

    $self->generate_file_from_template( $data_ref, $target_file, $template );
    return $target_file;
} ## end sub generate_chapter_html

sub generate_empty_chapter_html {
    my ( $self, $data_ref, $target_file, $template ) = @_;

    $target_file ||= $self->{target_dir} . "/" . sprintf( "%03d.html", $data_ref->{chapter_id} );
    $template ||= "$self->{template_dir}/../empty_chapter.html";

    $self->generate_file_from_template( $data_ref, $target_file, $template );

    return $target_file;
} ## end sub generate_empty_chapter_html

sub generate_index_html {
    my ( $self, $data_ref, $target_file, $template ) = @_;

    $target_file ||= $self->{target_dir} . "/" . sprintf( "%03d.html", 0 );
    $template ||= "$self->{template_dir}/index.html";

    $self->generate_file_from_template( $data_ref, $target_file, $template );

    return $target_file;
} ## end sub generate_index_html

no Moo;
1;

