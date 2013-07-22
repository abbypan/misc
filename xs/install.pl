#!/usr/bin/perl

system("cpan $_") while <DATA>;

__DATA__
Archive::Zip
Encode::Detect::CJK
File::Find::Rule
HTML::ElementTable
HTML::TableExtract
HTML::TreeBuilder
Moo
Parallel::ForkManager
Term::Menus
Term::ProgressBar
Text::Xslate
Web::Scraper
