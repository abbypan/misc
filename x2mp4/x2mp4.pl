#!/usr/bin/perl 

my ( $in, $out ) = @ARGV;
if ( !$out ) {
    $out = $in;
    $out =~ s/[^.]+$/mp4/;
}

my $info = `ffmpeg -i "$in" 2>&1 | grep fps`;
my ($rate) = $info =~ /(\d+) kb/;
if ( !$rate ) {
    $info = `ffmpeg -i "$in" 2>&1 | grep bitrate`;
    ($rate) = $info =~ /(\d+) kb/;
}

if ($rate) {
    print "video: $in -> $out, rate : $rate kb/s\n";
    my $cmd = qq[ffmpeg -i "$in" -y -strict -2 -b:${rate}k -o "$out"];
    print "$cmd\n";

    eval {
        system($cmd);
        unlink($in) if ( -f $out and -s $out );
    };
}
