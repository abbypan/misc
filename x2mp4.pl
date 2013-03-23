#!/usr/bin/perl 
#Usage: perl x2mp4.pl [infile] [outfile]
#调用ffmpeg做视频转换，保留原始视频的长宽、码率，默认转换成mp4格式

my ($in, $out) = @ARGV;
if(!$out){
    $out = $in;
    $out =~s/[^.]+$/mp4/;
}


my $info=`ffmpeg -i "$in" 2>&1 | grep fps`;
my ($rate) = $info=~/(\d+) kb/; 

print "video: $in -> $out, rate : $rate kb/s\n";
my $cmd =qq[ffmpeg -i "$in" -y -strict -2 -b:${rate}k -o "$out"];

eval { 
    `$cmd >/dev/null 2>&1`; 
    unlink($in) if(-f $out and -s $out);
};
