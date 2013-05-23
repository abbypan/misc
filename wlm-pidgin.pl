#!/usr/bin/perl
use XML::Simple;
use File::Spec;
use Encode;
use Time::Format qw/%time %strftime %manip/;
use Date::Manip;

my ( $self, $friend, $file ) = @ARGV;
die
	"Usage: wlm-pidgin [self wlm account] [friend wlm account] [xml log file]\n"
	unless ( defined $file );

parse_file( $self, $friend, $file );

sub parse_file {
	my ( $self, $friend, $file ) = @_;
	die "$file no exists!" unless ( -f $file );
	print "\r$file\n";

	my $xs   = XML::Simple->new();
	my $data = $xs->XMLin($file);
	mkdir($friend);
	chdir($friend);

	my %log;
	while ( my ( $k, $v ) = each %$data ) {
		if ( ref($v) eq 'ARRAY' ) {
			for my $i (@$v) {
				parse_message( \%log, $i );
			}
		}
		elsif ( ref($v) eq 'HASH' ) {
			parse_message( \%log, $v );
		}
	}

	while ( my ( $date, $day_log ) = each %log ) {
		my @times    = sort keys(%$day_log);
		my $filename = "$date.$times[0]+0000UTC.txt";
		$filename =~ s/://g;

		my $dm = ParseDate($date);
		$date =~ s/(\d*)-(\d*)-(\d*)/$1年$2月$3日/;
		( my $time = $times[0] ) =~ s/(\d*):(\d*):(\d*)/$1时$2分$3秒/;

		my $init =
			"Conversation with $friend at $date $weekday $time on $self (msn)\n";
		open( FH, '>>', $filename );
		print FH $init;

		for my $t (@times) {
			for my $info ( @{ $day_log->{$t} } ) {
				my $talk = "$info->[0]:  $info->[1]\n";
				$talk = "($time)  " . encode( 'utf8', $talk );
				print FH $talk;
			}
		}
		close(FH);
	}
	chdir( File::Spec->updir );
}

sub parse_message {
	my ( $log_ref, $data_ref ) = @_;
	my ( $date, $time, $user, $talk );

	return unless ( exists $data_ref->{'Date'} );
	$date = $data_ref->{'Date'};
	my ( $y, $m, $d ) = $date =~ /(\d*)-(\d*)-(\d*)/;
	$m = "0$m" if ( $m < 10 );
	$d = "0$d" if ( $d < 10 );
	$date = "$y-$m-$d";

	if ( exists $data_ref->{'From'} ) {
		$user = $data_ref->{'From'}->{'User'}->{'FriendlyName'};
	}
	elsif ( exists $data_ref->{'User'} ) {
		$user = $data_ref->{'User'}->{'FriendlyName'};
	}

	$talk = $data_ref->{'Text'}->{'content'};
	$talk =~ s/^\s*//g;

	$time = $data_ref->{'Time'};

	push @{ $log_ref->{$date}->{$time} }, [ $user, $talk ];
}
