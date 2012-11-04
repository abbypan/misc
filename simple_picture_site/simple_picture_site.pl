#!/usr/bin/perl

our $TXT2TAGS_BIN = 'txt2tags';

my $title = 'TEST';
my $dirs = get_image_dirs();
create_index_html($title, $dirs);
create_image_html($_) for @$dirs;

sub get_image_dirs {
	my @dirs = sort { $b cmp $a } grep { -d $_ } glob('*');
	return \@dirs;
}

sub create_image_html {
	my ($dir) = @_;
	my @imgs = sort glob("$dir/*.jpg");
	my @img_links = map { "[../$_]" } @imgs;
	my $img_info = join("\n", @img_links);

my $t2t = <<__T2T__;
$dir


%!includeconf: ../config.t2t
%!style   : ../site.css

$img_info
__T2T__
my $t2t_file = write_txt("$dir/index.t2t", $t2t);
conv_t2t_to_html($t2t_file);
}

sub create_index_html {
my ($title, $dirs) = @_;
my @dir_links = map { "- [$_  ./$_/index.html]" } @$dirs;
my $dir_info = join("\n", @dir_links);
my $t2t = <<__T2T__;
$title


%!includeconf: config.t2t
%!style   : ./site.css

=INFO=
- COMPANY : {company}
- PHONE : {phone}
- EMAIL : {email}
- TAX   : {tax}
- ADDRESS : {address}


=CONTENT=
$dir_info
__T2T__
my $t2t_file = write_txt('index.t2t', $t2t);
conv_t2t_to_html($t2t_file);
}

sub write_txt {
	my ($file, $txt) = @_;
	open my $fh, '>', $file;
	print $fh $txt;
	close $fh;
	return $file;
}

sub conv_t2t_to_html {
	my ($t2t) =@_;
	system("$TXT2TAGS_BIN -t html $t2t");
	unlink($t2t);
}
