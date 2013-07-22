#!/usr/bin/perl

system("cpan $_") while <DATA>;

__DATA__
HTML::FormatText
HTML::TreeBuilder
Config::Simple
Authen::SASL
MIME::Lite
Net::SMTP::SSL
WordPress::XMLRPC
