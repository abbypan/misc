#!/usr/bin/perl

my $interface_num = 4;

my ($url, $dst_file) = @ARGV;
#my $url = "http://www.gymnastike.org/coverage/251079-2013-World-Championships/video/720878-China-Zeng-Siqi-FX"; 
if(!$dst_file){
    $dst_file=$url;
    $dst_file=~s#^.*/##;
    $dst_file.=".mp4";
}

my $cap_file = capture_url($url, "$dst_file.cap", $interface_num);
download_rtmp($cap_file, $dst_file);
unlink($cap_file);

sub download_rtmp {
    my ($cap_file, $dst_file) = @_;
    my $conn = `tshark -r "$cap_file" -Y "rtmpt"|grep connect`;
    my ($dst_ip, $conn_url) = $conn=~/-> (.+?) RTMP.*?connect\('(.+)'\)\n/;
    my $play = `tshark -r "$cap_file" -Y "rtmpt"|grep play`;
    my ($play_url) = $play=~/RTMP.*?play\('(.+)'\)\n/;
    my $dump_cmd=qq[rtmpdump -r "rtmp://$dst_ip/$conn_url" -y "$play_url" -o "$dst_file"];
    print $dump_cmd, "\n";
    system($dump_cmd);
    return $dst_file;
}

sub capture_url {
    my ($url, $cap_file, $interface_num) = @_;
    print "analyse : $url\n";

    my $ahk=qq[
    Run, tshark.exe -i $interface_num -w $cap_file
    Run, iexplore.exe  $url
    sleep 30000
    Loop {
    Process,Close,iexplore.exe
    if !ErrorLevel
    break
    }
    Process, close, tshark.exe
    ExitApp
    Return
    ];

    my $ahk_file = "$cap_file.ahk";
    open my $fh, '>', $ahk_file;
    print $fh $ahk;
    close $fh;

    `autohotkey $ahk_file`;
    unlink($ahk_file);

    return $cap_file;
}
