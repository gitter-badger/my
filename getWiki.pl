#!/usr/local/bin/perl -w
use strict;

use Encode;
use LWP;

sub getFilename {
    my ($filename) = @_;

    $filename =~ s/.*wgTitle="(.*?)".*/$1/s;

    $filename =~ s/&amp;/&/;

    $filename =~ s/(.?)/sprintf("%02X", ord($1))/eg;
    $filename =~ s/00//;
    $filename .= ".txt";

    return $filename;
}

sub Wiki {
    my ($ua, $url) = @_;
    my $req = HTTP::Request->new(GET => $url);
    my $res = $ua->request($req);

    if ($res->is_success) {
        my $text = $res->content;
        Encode::from_to($text, "utf8", "euc-jp");

        my $filename = getFilename($text);
        $text =~ s/.*<textarea.*?>(.*)<\/textarea>.*/$1/s; # textarea内のデータのみにする

        my @text = split("\n", $text);
        foreach(@text) {
            s/<br.*?>/\n/;
            s/^\*(.*)/-$1/;
            s/^\*\*(.*)/--$1/;
            s/^\*\*\*(.*)/---$1/;
            s/^===(.*)===\s*$/***$1/g;
            s/^==(.*)==\s*$/**$1/g;
            s/^=(.*)=\s*$/*$1/g;
            s/^###(.*?[^=]+$)/+++$1/;
            s/^##(.*?[^=]+$)/++$1/;
            s/^#(.*?[^=]+$)/+$1/;
            s/^:::(.*?)/>>>$1/;
            s/^::(.*?)/>>$1/;
            s/^:(.*?)/>$1/;
            s/^; (.*?) : (.*?)/; $1 \| $2/;
            s/<center>(.*?)<\/center>/CENTER:$1/g;
        }
        $text = join("\n", @text);

        my $fh;
        open($fh, '>', "wiki/$filename");
        print $fh $text;
        close($fh);
    }
}

sub toEdit {
    my($ua, $url) = @_;
    my $req = HTTP::Request->new(GET => $url);
    my $res = $ua->request($req);
    my $text = $res->content;
    #$text =~ s/.*<div class="editsection".*?href="(.*?)&amp;action=edit.*/$1/s;
    $text =~ s/.*href="(.*?)&amp;action=edit".*/$1/s;
    $text = "http://ja.wikipedia.org" . $text . "&action=edit";
    
    #my $text = $url . "&action=edit";
    return $text;
}

sub allPageStep2 {
    my($ua, $url) = @_;
    my @urls;

    $url =~ s/&amp;/&/g;
    
    my $req = HTTP::Request->new(GET => $url);
    my $res = $ua->request($req);
    my $text = $res->content;
    $text =~ s/.*<table class="mw-allpages-table-chunk"(.*?)<\/table>.*/$1/s;

    foreach (split(" ", $text)) {
        if (/href=/) {
            s/href="(.*)"/$1/;
            push(@urls, "http://ja.wikipedia.org/$_");
        }
    }

    return @urls;
}

sub allPageStep1 {
    my($ua, $url) = @_;
    my @urls;
    my @tmp_urls;
    my $urls_len;

    $url =~ s/&amp;/&/g;
    my $req = HTTP::Request->new(GET => $url);
    my $res = $ua->request($req);
    my $text = $res->content;

    if ($text =~ m/<table class="allpageslist"/) {
        $text =~ s/.*<table class="allpageslist"(.*?)<\/table>.*/$1/s;

        foreach (split(" ", $text)) {
            if (/href=/) {
                s/href="(.*)".*/$1/;
                push(@tmp_urls, "http://ja.wikipedia.org/$_");
            }
        }

        my %tmp;
        @tmp_urls = grep( !$tmp{$_}++, @tmp_urls );

        $urls_len = @tmp_urls; 
        if ($urls_len != 0) {
            foreach (@tmp_urls) {
                push(@urls, allPageStep1($ua, $_));
            }
        }

        return @urls;
    } else {
        return $url;
    }
}


#
# MAIN
#

my $ua = LWP::UserAgent->new;
$ua->timeout(10);
$ua->agent('Mozilla');


#foreach (allPageStep1($ua, 'http://ja.wikipedia.org/wiki/%E7%89%B9%E5%88%A5:Allpages')) {
    #my @url = allPageStep2($ua, $_);
    
    my @url = allPageStep2($ua,
        'http://ja.wikipedia.org//w/index.php?title=%E7%89%B9%E5%88%A5:%E3%83%9A%E3%83%BC%E3%82%B8%E4%B8%80%E8%A6%A7&from=%21&to=.bm');

    foreach(@url) {
        my $url = toEdit($ua, $_);
        print "$url\n";
        Wiki($ua, $url);
    }
#}
